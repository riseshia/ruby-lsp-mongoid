# frozen_string_literal: true

require_relative "../../ruby_lsp_mongoid/version"
require_relative "indexing_enhancement"

module RubyLsp
  module Mongoid
    class Addon < ::RubyLsp::Addon
      def activate(global_state, outgoing_queue)
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
    end
  end
end
