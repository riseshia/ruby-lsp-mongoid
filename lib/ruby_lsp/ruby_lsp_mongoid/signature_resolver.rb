# frozen_string_literal: true

module RubyLsp
  module Mongoid
    # Resolves method signatures from Mongoid modules in the Ruby LSP index.
    # Used to update method signatures after initial indexing is complete.
    module SignatureResolver
      # Mongoid modules that provide instance methods
      INSTANCE_METHOD_SOURCES = [
        "Mongoid::Persistable::Savable",
        "Mongoid::Persistable::Updatable",
        "Mongoid::Persistable::Deletable",
        "Mongoid::Persistable::Destroyable",
        "Mongoid::Persistable::Upsertable",
        "Mongoid::Attributes",
        "Mongoid::Reloadable",
        "Mongoid::Stateful",
        "Mongoid::Changeable",
        "Mongoid::Inspectable",
      ].freeze

      # Mongoid modules that provide class methods
      CLASS_METHOD_SOURCES = [
        "Mongoid::Findable",
        "Mongoid::Criteria",
        "Mongoid::Persistable::Creatable::ClassMethods",
        "Mongoid::Clients::Sessions::ClassMethods",
      ].freeze

      # Core instance methods to look up signatures for
      CORE_INSTANCE_METHODS = %w[
        save save! update update! destroy delete upsert reload
        new_record? persisted? valid? changed?
        attributes attributes= assign_attributes read_attribute write_attribute
        changes errors to_key to_param model_name inspect
      ].freeze

      # Core class methods to look up signatures for
      CORE_CLASS_METHODS = %w[
        all where find find_by find_by! first last count exists? distinct
        create create! new build update_all delete_all destroy_all
        collection database
      ].freeze

      # Resolve instance method signature from Mongoid modules
      # @param index [RubyIndexer::Index] Ruby LSP index
      # @param method_name [String] Method name to look up
      # @return [Array<RubyIndexer::Entry::Signature>, nil] Signatures or nil if not found
      def resolve_instance_method_signature(index, method_name)
        INSTANCE_METHOD_SOURCES.each do |module_name|
          entries = index.resolve_method(method_name, module_name)
          next unless entries&.any?

          entry = entries.first
          return entry.signatures if entry.respond_to?(:signatures) && entry.signatures.any?
        end

        nil
      end

      # Resolve class method signature from Mongoid modules
      # @param index [RubyIndexer::Index] Ruby LSP index
      # @param method_name [String] Method name to look up
      # @return [Array<RubyIndexer::Entry::Signature>, nil] Signatures or nil if not found
      def resolve_class_method_signature(index, method_name)
        CLASS_METHOD_SOURCES.each do |module_name|
          entries = index.resolve_method(method_name, module_name)
          next unless entries&.any?

          entry = entries.first
          return entry.signatures if entry.respond_to?(:signatures) && entry.signatures.any?
        end

        nil
      end
    end
  end
end
