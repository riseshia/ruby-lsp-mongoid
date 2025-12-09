# frozen_string_literal: true

require "ruby_lsp/ruby_lsp_mongoid"
require "ruby_lsp/internal"

RSpec.describe RubyLsp::Mongoid::SignatureResolver do
  let(:test_class) do
    Class.new do
      include RubyLsp::Mongoid::SignatureResolver
    end
  end

  let(:resolver) { test_class.new }
  let(:index) { RubyIndexer::Index.new }
  let(:indexable_path) { URI::Generic.from_path(path: "/fake_mongoid.rb") }

  after do
    index.delete(indexable_path)
  end

  describe "#resolve_instance_method_signature" do
    it "returns signatures from Mongoid::Persistable::Savable" do
      index.index_single(indexable_path, <<~RUBY)
        module Mongoid
          module Persistable
            module Savable
              def save(validate: true)
              end
            end
          end
        end
      RUBY

      signatures = resolver.resolve_instance_method_signature(index, "save")

      expect(signatures).not_to be_nil
      expect(signatures.first.parameters.size).to eq(1)
      expect(signatures.first.parameters.first.name).to eq(:validate)
    end

    it "returns signatures from Mongoid::Attributes" do
      index.index_single(indexable_path, <<~RUBY)
        module Mongoid
          module Attributes
            def read_attribute(name)
            end
          end
        end
      RUBY

      signatures = resolver.resolve_instance_method_signature(index, "read_attribute")

      expect(signatures).not_to be_nil
      expect(signatures.first.parameters.size).to eq(1)
      expect(signatures.first.parameters.first.name).to eq(:name)
    end

    it "returns nil when method not found in any source module" do
      signatures = resolver.resolve_instance_method_signature(index, "nonexistent_method")

      expect(signatures).to be_nil
    end

    it "searches multiple source modules" do
      index.index_single(indexable_path, <<~RUBY)
        module Mongoid
          module Reloadable
            def reload
            end
          end
        end
      RUBY

      signatures = resolver.resolve_instance_method_signature(index, "reload")

      expect(signatures).not_to be_nil
    end
  end

  describe "#resolve_class_method_signature" do
    it "returns signatures from Mongoid::Findable" do
      index.index_single(indexable_path, <<~RUBY)
        module Mongoid
          module Findable
            def find(id)
            end
          end
        end
      RUBY

      signatures = resolver.resolve_class_method_signature(index, "find")

      expect(signatures).not_to be_nil
      expect(signatures.first.parameters.size).to eq(1)
      expect(signatures.first.parameters.first.name).to eq(:id)
    end

    it "returns signatures from Mongoid::Criteria" do
      index.index_single(indexable_path, <<~RUBY)
        module Mongoid
          class Criteria
            def where(conditions = {})
            end
          end
        end
      RUBY

      signatures = resolver.resolve_class_method_signature(index, "where")

      expect(signatures).not_to be_nil
      expect(signatures.first.parameters.size).to eq(1)
      expect(signatures.first.parameters.first.name).to eq(:conditions)
    end

    it "returns nil when method not found in any source module" do
      signatures = resolver.resolve_class_method_signature(index, "nonexistent_method")

      expect(signatures).to be_nil
    end
  end

  describe "constants" do
    it "defines CORE_INSTANCE_METHODS" do
      expect(RubyLsp::Mongoid::SignatureResolver::CORE_INSTANCE_METHODS).to include("save", "update", "destroy")
    end

    it "defines CORE_CLASS_METHODS" do
      expect(RubyLsp::Mongoid::SignatureResolver::CORE_CLASS_METHODS).to include("find", "where", "create")
    end

    it "defines INSTANCE_METHOD_SOURCES" do
      expect(RubyLsp::Mongoid::SignatureResolver::INSTANCE_METHOD_SOURCES).to include("Mongoid::Persistable::Savable")
    end

    it "defines CLASS_METHOD_SOURCES" do
      expect(RubyLsp::Mongoid::SignatureResolver::CLASS_METHOD_SOURCES).to include("Mongoid::Findable")
    end
  end
end
