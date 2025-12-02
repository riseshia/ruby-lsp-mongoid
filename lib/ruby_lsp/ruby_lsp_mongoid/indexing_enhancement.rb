# frozen_string_literal: true

module RubyLsp
  module Mongoid
    class IndexingEnhancement < RubyIndexer::Enhancement
      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
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

      def handle_field(call_node)
        name = extract_name(call_node)
        return unless name

        loc = call_node.location
        add_accessor_methods(name, loc)

        # Handle as: option for field alias
        alias_name = extract_as_option(call_node)
        add_accessor_methods(alias_name, loc) if alias_name
      end

      def handle_accessor_dsl(call_node)
        name = extract_name(call_node)
        return unless name

        add_accessor_methods(name, call_node.location)
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

        add_singleton_method(name.to_s, call_node.location, owner)
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

      def extract_as_option(call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        # Find keyword hash in arguments
        keyword_hash = arguments.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
        return unless keyword_hash

        # Look for as: key
        as_element = keyword_hash.elements.find do |element|
          element.is_a?(Prism::AssocNode) &&
            element.key.is_a?(Prism::SymbolNode) &&
            element.key.value == "as"
        end

        return unless as_element

        case as_element.value
        when Prism::SymbolNode
          as_element.value.value
        when Prism::StringNode
          as_element.value.content
        end
      end

      def add_accessor_methods(name, location)
        reader_signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method(name.to_s, location, reader_signatures)

        writer_signatures = [
          RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: :value)]),
        ]
        @listener.add_method("#{name}=", location, writer_signatures)
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
