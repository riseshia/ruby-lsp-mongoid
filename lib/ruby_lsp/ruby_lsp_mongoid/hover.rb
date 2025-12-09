# frozen_string_literal: true

module RubyLsp
  module Mongoid
    class Hover
      include RubyLsp::Requests::Support::Common

      FIELD_DSL = :field
      ASSOCIATION_DSLS = %i[
        embeds_many embeds_one embedded_in
        has_many has_one belongs_to has_and_belongs_to_many
      ].freeze

      def initialize(response_builder, node_context, index, dispatcher)
        @response_builder = response_builder
        @node_context = node_context
        @index = index

        dispatcher.register(self, :on_symbol_node_enter)
      end

      def on_symbol_node_enter(node)
        call_node = @node_context.call_node
        return unless call_node.is_a?(Prism::CallNode)

        if call_node.name == FIELD_DSL
          handle_field(call_node)
        elsif ASSOCIATION_DSLS.include?(call_node.name)
          handle_association(call_node)
        end
      end

      private

      def handle_field(node)
        owner = @node_context.nesting.last
        return unless owner

        name = extract_name(node)
        return unless name

        entries = @index.resolve_method(name.to_s, owner)
        return unless entries&.any?

        entry = entries.first

        # Build hover content with signature and options
        content_parts = []

        # Add method signature
        signature = format_signature(name.to_s, entry)
        content_parts << signature if signature

        # Add field options from comments
        comments = entry.comments
        content_parts << comments if comments && !comments.empty?

        return if content_parts.empty?

        @response_builder.push(content_parts.join("\n\n"), category: :documentation)
      end

      def handle_association(node)
        association_type = node.name
        association_name = extract_name(node)
        return unless association_name

        class_name = extract_class_name_option(node) || classify(association_name)
        generate_association_hover(class_name, association_type)
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

      def extract_class_name_option(call_node)
        arguments = call_node.arguments&.arguments
        return unless arguments

        keyword_hash = arguments.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
        return unless keyword_hash

        element = keyword_hash.elements.find do |el|
          el.is_a?(Prism::AssocNode) &&
            el.key.is_a?(Prism::SymbolNode) &&
            el.key.value == "class_name"
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

      def classify(name)
        singular = singularize(name)
        singular.to_s.split("_").map(&:capitalize).join
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

      def generate_association_hover(class_name, association_type)
        entries = @index[class_name]

        if entries&.any?
          entry = entries.first
          line = entry.location.start_line
          content = "#{association_type}: [#{class_name}](#{entry.uri}#L#{line})"
        else
          content = "#{association_type}: #{class_name}"
        end

        @response_builder.push(content, category: :documentation)
      end

      def format_signature(method_name, entry)
        return nil unless entry.respond_to?(:signatures) && entry.signatures.any?

        sig = entry.signatures.first
        return nil if sig.parameters.empty?

        params = sig.parameters.map { |param| format_parameter(param) }.join(", ")
        "```ruby\ndef #{method_name}(#{params})\n```"
      end

      def format_parameter(param)
        case param
        when RubyIndexer::Entry::RequiredParameter
          param.name.to_s
        when RubyIndexer::Entry::OptionalParameter
          "#{param.name} = nil"
        when RubyIndexer::Entry::KeywordParameter
          "#{param.name}:"
        when RubyIndexer::Entry::OptionalKeywordParameter
          "#{param.name}: nil"
        when RubyIndexer::Entry::RestParameter
          "*#{param.name}"
        when RubyIndexer::Entry::KeywordRestParameter
          "**#{param.name}"
        when RubyIndexer::Entry::BlockParameter
          "&#{param.name}"
        else
          param.name.to_s
        end
      end
    end
  end
end
