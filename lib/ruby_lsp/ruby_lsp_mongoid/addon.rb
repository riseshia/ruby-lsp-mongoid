# frozen_string_literal: true

require_relative "../../ruby_lsp_mongoid/version"
require_relative "indexing_enhancement"
require_relative "hover"

module RubyLsp
  module Mongoid
    class Addon < ::RubyLsp::Addon
      def activate(global_state, outgoing_queue)
        @global_state = global_state
        @outgoing_queue = outgoing_queue
        @outgoing_queue << Notification.window_log_message("Activating Ruby LSP Mongoid add-on v#{VERSION}")
      end

      def deactivate; end

      def name
        "Ruby LSP Mongoid"
      end

      def version
        VERSION
      end

      def create_hover_listener(response_builder, node_context, dispatcher)
        return unless @global_state

        Hover.new(response_builder, node_context, @global_state.index, dispatcher)
      end
    end
  end
end
