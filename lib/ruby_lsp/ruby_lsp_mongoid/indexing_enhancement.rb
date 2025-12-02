# frozen_string_literal: true

module RubyLsp
  module Mongoid
    class IndexingEnhancement < RubyIndexer::Enhancement
      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
        when :field, :embeds_many, :embedded_in
          handle_accessor_dsl(call_node)
        when :has_many, :has_and_belongs_to_many
          handle_many_association(call_node)
        when :has_one, :belongs_to, :embeds_one
          handle_singular_association(call_node)
        end
      end

      def on_call_node_leave(call_node); end

      private

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
