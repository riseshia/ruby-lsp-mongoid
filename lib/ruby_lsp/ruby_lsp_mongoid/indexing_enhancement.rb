# frozen_string_literal: true

module RubyLsp
  module Mongoid
    class IndexingEnhancement < RubyIndexer::Enhancement
      def initialize(listener)
        super
      end

      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
        when :include
          handle_include(call_node)
        when :field
          handle_field(call_node)
        when :embeds_many, :embedded_in
          handle_accessor_dsl(call_node)
        when :has_many, :has_and_belongs_to_many
          handle_many_association(call_node)
        when :has_one, :belongs_to, :embeds_one
          handle_singular_association(call_node)
        when :scope
          handle_scope(call_node)
        end
      end

      def on_call_node_leave(call_node); end

      private

      # Core instance methods automatically added by Mongoid::Document
      CORE_INSTANCE_METHODS = %w[
        save save! update update! destroy delete upsert reload
        new_record? persisted? valid? changed?
        attributes attributes= assign_attributes read_attribute write_attribute changes errors
        to_key to_param model_name inspect
      ].freeze

      # Class methods automatically added by Mongoid::Document
      CORE_CLASS_METHODS = %w[
        all where find find_by find_by! first last count exists? distinct
        create create! new build
        update_all delete_all destroy_all
        collection database
      ].freeze

      def handle_include(call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        # Check if including Mongoid::Document or ApplicationDocument
        first_arg = arguments.first
        module_name = case first_arg
                      when Prism::ConstantReadNode
                        first_arg.name.to_s
                      when Prism::ConstantPathNode
                        first_arg.full_name
                      end

        # Support both Mongoid::Document and ApplicationDocument (common Rails pattern)
        return unless module_name == "Mongoid::Document" || module_name == "ApplicationDocument"

        owner = @listener.current_owner
        return unless owner

        loc = call_node.location

        # Add _id and id accessor methods (always present in Mongoid documents)
        add_accessor_methods("_id", loc)
        add_accessor_methods("id", loc)

        # Add core instance methods
        CORE_INSTANCE_METHODS.each do |method_name|
          add_core_method(method_name, loc)
        end

        # Add core class methods
        CORE_CLASS_METHODS.each do |method_name|
          add_singleton_method(method_name, loc, owner)
        end
      end

      def handle_field(call_node)
        name = extract_name(call_node)
        return unless name

        loc = call_node.location
        comment = build_field_options_comment(call_node)

        add_accessor_methods(name, loc, comments: comment)

        # Handle as: option for field alias
        alias_name = extract_option_value(call_node, "as")
        add_accessor_methods(alias_name, loc, comments: comment) if alias_name
      end

      def handle_accessor_dsl(call_node)
        name = extract_name(call_node)
        return unless name

        loc = call_node.location

        add_accessor_methods(name, loc)
      end

      def handle_many_association(call_node)
        name = extract_name(call_node)
        return unless name

        loc = call_node.location

        add_accessor_methods(name, loc)

        singular_name = singularize(name)
        add_accessor_methods("#{singular_name}_ids", loc)
      end

      def handle_singular_association(call_node)
        name = extract_name(call_node)
        return unless name

        loc = call_node.location

        add_accessor_methods(name, loc)
        add_builder_methods(name, loc)
      end

      def handle_scope(call_node)
        name = extract_name(call_node)
        return unless name

        owner = @listener.current_owner
        return unless owner

        loc = call_node.location

        add_singleton_method(name.to_s, loc, owner)
      end

      def extract_name(call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        name_arg = arguments.first

        case name_arg
        when Prism::SymbolNode
          name_arg.value
        when Prism::StringNode
          name_arg.content
        end
      end

      def extract_option_value(call_node, key)
        arguments = call_node.arguments&.arguments
        return unless arguments

        keyword_hash = arguments.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
        return unless keyword_hash

        element = keyword_hash.elements.find do |el|
          el.is_a?(Prism::AssocNode) &&
            el.key.is_a?(Prism::SymbolNode) &&
            el.key.value == key
        end

        return unless element

        case element.value
        when Prism::SymbolNode
          element.value.value
        when Prism::StringNode
          element.value.content
        when Prism::ConstantReadNode
          element.value.name.to_s
        when Prism::ConstantPathNode
          element.value.full_name
        end
      end

      def extract_option_source(call_node, key)
        arguments = call_node.arguments&.arguments
        return unless arguments

        keyword_hash = arguments.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
        return unless keyword_hash

        element = keyword_hash.elements.find do |el|
          el.is_a?(Prism::AssocNode) &&
            el.key.is_a?(Prism::SymbolNode) &&
            el.key.value == key
        end

        element&.value&.slice
      end

      def build_field_options_comment(call_node)
        options = []

        type_value = extract_option_value(call_node, "type")
        options << "type: #{type_value}" if type_value

        as_value = extract_option_value(call_node, "as")
        options << "as: #{as_value}" if as_value

        default_source = extract_option_source(call_node, "default")
        options << "default: #{default_source}" if default_source

        options.any? ? options.join(", ") : nil
      end

      def add_accessor_methods(name, location, comments: nil)
        reader_signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method(name.to_s, location, reader_signatures, comments: comments)

        writer_signatures = [
          RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: :value)]),
        ]
        @listener.add_method("#{name}=", location, writer_signatures, comments: comments)
      end

      def add_core_method(name, location)
        signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method(name.to_s, location, signatures)
      end

      def add_builder_methods(name, location)
        builder_signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method("build_#{name}", location, builder_signatures)
        @listener.add_method("create_#{name}", location, builder_signatures)
        @listener.add_method("create_#{name}!", location, builder_signatures)
      end

      def add_singleton_method(name, node_location, owner)
        index = @listener.instance_variable_get(:@index)
        code_units_cache = @listener.instance_variable_get(:@code_units_cache)
        uri = @listener.instance_variable_get(:@uri)

        location = RubyIndexer::Location.from_prism_location(node_location, code_units_cache)
        singleton = index.existing_or_new_singleton_class(owner.name)
        signatures = [RubyIndexer::Entry::Signature.new([])]

        index.add(RubyIndexer::Entry::Method.new(
          name,
          uri,
          location,
          location,
          "",
          signatures,
          :public,
          singleton,
        ))
      end

      def singularize(name)
        name_str = name.to_s
        if name_str.end_with?("ies")
          name_str[0..-4] + "y"
        elsif name_str.end_with?("s")
          name_str[0..-2]
        else
          name_str
        end
      end
    end
  end
end
