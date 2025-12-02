# frozen_string_literal: true

module RubyLsp
  module Mongoid
    class IndexingEnhancement < RubyIndexer::Enhancement
      def on_call_node_enter(call_node)
        owner = @listener.current_owner
        return unless owner

        case call_node.name
        when :field
          handle_field(owner, call_node)
        end
      end

      def on_call_node_leave(call_node); end

      private

      def handle_field(owner, call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        name_arg = arguments.first

        name = case name_arg
        when Prism::SymbolNode
          name_arg.value
        when Prism::StringNode
          name_arg.content
        end

        return unless name

        loc = call_node.location

        # Reader
        reader_signatures = [RubyIndexer::Entry::Signature.new([])]
        @listener.add_method(name, loc, reader_signatures)

        # Writer
        writer_signatures = [
          RubyIndexer::Entry::Signature.new([RubyIndexer::Entry::RequiredParameter.new(name: :value)]),
        ]
        @listener.add_method("#{name}=", loc, writer_signatures)
      end
    end
  end
end
