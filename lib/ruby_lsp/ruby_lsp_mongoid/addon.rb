# frozen_string_literal: true

require_relative "../../ruby_lsp_mongoid/version"
require_relative "signature_resolver"
require_relative "indexing_enhancement"
require_relative "hover"

module RubyLsp
  module Mongoid
    class Addon < ::RubyLsp::Addon
      include SignatureResolver

      def activate(global_state, outgoing_queue)
        @global_state = global_state
        @outgoing_queue = outgoing_queue
        @outgoing_queue << Notification.window_log_message("Activating Ruby LSP Mongoid add-on v#{VERSION}")

        # Start background thread to update signatures after indexing completes
        @signature_update_thread = Thread.new { wait_for_indexing_and_update_signatures }
      end

      def deactivate
        @signature_update_thread&.kill
      end

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

      private

      def wait_for_indexing_and_update_signatures
        return unless @global_state

        index = @global_state.index

        # Wait for initial indexing to complete
        sleep(0.1) until index.instance_variable_get(:@initial_indexing_completed)

        update_mongoid_signatures(index)
      rescue StandardError => e
        @outgoing_queue << Notification.window_log_message(
          "Ruby LSP Mongoid: Error updating signatures: #{e.message}",
        )
      end

      def update_mongoid_signatures(index)
        updated_count = 0

        # Update instance method signatures
        CORE_INSTANCE_METHODS.each do |method_name|
          mongoid_signatures = resolve_instance_method_signature(index, method_name)
          next unless mongoid_signatures

          updated_count += update_method_signatures_for_mongoid_models(index, method_name, mongoid_signatures)
        end

        # Update class method signatures
        CORE_CLASS_METHODS.each do |method_name|
          mongoid_signatures = resolve_class_method_signature(index, method_name)
          next unless mongoid_signatures

          updated_count += update_singleton_method_signatures_for_mongoid_models(
            index,
            method_name,
            mongoid_signatures,
          )
        end

        if updated_count > 0
          @outgoing_queue << Notification.window_log_message(
            "Ruby LSP Mongoid: Updated #{updated_count} method signatures from Mongoid modules",
          )
        end
      end

      def update_method_signatures_for_mongoid_models(index, method_name, new_signatures)
        updated = 0

        # Find all classes that have this method registered by our addon
        # We look for methods that were registered with empty signatures
        # Use dup to avoid "can't add a new key into hash during iteration" error
        # when ruby-lsp modifies the index concurrently
        entries_snapshot = index.instance_variable_get(:@entries).dup
        entries_snapshot.each do |_name, entries|
          entries.each do |entry|
            next unless entry.is_a?(RubyIndexer::Entry::Method)
            next unless entry.name == method_name
            next unless entry.signatures.empty? || entry.signatures.first.parameters.empty?

            # Update the signatures
            entry.instance_variable_set(:@signatures, new_signatures)
            updated += 1
          end
        end

        updated
      end

      def update_singleton_method_signatures_for_mongoid_models(index, method_name, new_signatures)
        updated = 0

        # Use dup to avoid "can't add a new key into hash during iteration" error
        entries_snapshot = index.instance_variable_get(:@entries).dup
        entries_snapshot.each do |_name, entries|
          entries.each do |entry|
            next unless entry.is_a?(RubyIndexer::Entry::Method)
            next unless entry.name == method_name
            next unless entry.owner.is_a?(RubyIndexer::Entry::SingletonClass)
            next unless entry.signatures.empty? || entry.signatures.first.parameters.empty?

            entry.instance_variable_set(:@signatures, new_signatures)
            updated += 1
          end
        end

        updated
      end
    end
  end
end
