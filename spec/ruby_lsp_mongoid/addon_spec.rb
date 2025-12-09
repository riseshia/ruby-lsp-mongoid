# frozen_string_literal: true

require "ruby_lsp/ruby_lsp_mongoid"
require "ruby_lsp/internal"

RSpec.describe RubyLsp::Mongoid::Addon do
  let(:addon) { described_class.new }
  let(:index) { RubyIndexer::Index.new }
  let(:outgoing_queue) { [] }
  let(:global_state) { double("GlobalState", index: index) }

  after do
    addon.deactivate if addon
  end

  describe "signature update after indexing" do
    it "updates instance method signatures from Mongoid modules after indexing completes" do
      # Index Mongoid module with save method
      mongoid_path = URI::Generic.from_path(path: "/fake_mongoid.rb")
      index.index_single(mongoid_path, <<~RUBY)
        module Mongoid
          module Persistable
            module Savable
              def save(validate: true)
              end
            end
          end
        end
      RUBY

      # Index a Mongoid model with save method (empty signature initially)
      model_path = URI::Generic.from_path(path: "/fake_model.rb")
      index.index_single(model_path, <<~RUBY)
        class User
          include Mongoid::Document
        end
      RUBY

      # Verify save method exists with empty parameters initially
      entries = index.resolve_method("save", "User")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters).to be_empty

      # Mark indexing as complete
      index.instance_variable_set(:@initial_indexing_completed, true)

      # Activate addon (starts background thread)
      addon.activate(global_state, outgoing_queue)

      # Wait for signature update to complete
      sleep(0.3)

      # Verify save method now has signature from Mongoid module
      entries = index.resolve_method("save", "User")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters.size).to eq(1)
      expect(entries.first.signatures.first.parameters.first.name).to eq(:validate)

      index.delete(mongoid_path)
      index.delete(model_path)
    end

    it "updates class method signatures from Mongoid modules after indexing completes" do
      # Index Mongoid module with find method
      mongoid_path = URI::Generic.from_path(path: "/fake_mongoid.rb")
      index.index_single(mongoid_path, <<~RUBY)
        module Mongoid
          module Findable
            def find(id)
            end
          end
        end
      RUBY

      # Index a Mongoid model with find class method (empty signature initially)
      model_path = URI::Generic.from_path(path: "/fake_model.rb")
      index.index_single(model_path, <<~RUBY)
        class Post
          include Mongoid::Document
        end
      RUBY

      # Verify find method exists with empty parameters initially
      entries = index.resolve_method("find", "Post::<Class:Post>")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters).to be_empty

      # Mark indexing as complete
      index.instance_variable_set(:@initial_indexing_completed, true)

      # Activate addon
      addon.activate(global_state, outgoing_queue)

      # Wait for signature update to complete
      sleep(0.3)

      # Verify find method now has signature from Mongoid module
      entries = index.resolve_method("find", "Post::<Class:Post>")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters.size).to eq(1)
      expect(entries.first.signatures.first.parameters.first.name).to eq(:id)

      index.delete(mongoid_path)
      index.delete(model_path)
    end

    it "updates multiple method signatures across multiple models" do
      # Index Mongoid modules
      mongoid_path = URI::Generic.from_path(path: "/fake_mongoid.rb")
      index.index_single(mongoid_path, <<~RUBY)
        module Mongoid
          module Persistable
            module Savable
              def save(validate: true)
              end
            end
            module Updatable
              def update(attributes)
              end
            end
          end
          module Findable
            def find(id)
            end
            def where(conditions = {})
            end
          end
        end
      RUBY

      # Index multiple Mongoid models
      user_path = URI::Generic.from_path(path: "/user.rb")
      index.index_single(user_path, <<~RUBY)
        class User
          include Mongoid::Document
        end
      RUBY

      post_path = URI::Generic.from_path(path: "/post.rb")
      index.index_single(post_path, <<~RUBY)
        class Post
          include Mongoid::Document
        end
      RUBY

      # Mark indexing as complete
      index.instance_variable_set(:@initial_indexing_completed, true)

      # Activate addon
      addon.activate(global_state, outgoing_queue)

      # Wait for signature update to complete
      sleep(0.3)

      # Verify User instance methods have signatures
      user_save = index.resolve_method("save", "User")
      expect(user_save.first.signatures).not_to be_empty
      expect(user_save.first.signatures.first.parameters.first.name).to eq(:validate)

      user_update = index.resolve_method("update", "User")
      expect(user_update.first.signatures).not_to be_empty
      expect(user_update.first.signatures.first.parameters.first.name).to eq(:attributes)

      # Verify User class methods have signatures
      user_find = index.resolve_method("find", "User::<Class:User>")
      expect(user_find.first.signatures).not_to be_empty
      expect(user_find.first.signatures.first.parameters.first.name).to eq(:id)

      user_where = index.resolve_method("where", "User::<Class:User>")
      expect(user_where.first.signatures).not_to be_empty
      expect(user_where.first.signatures.first.parameters.first.name).to eq(:conditions)

      # Verify Post methods also have signatures
      post_save = index.resolve_method("save", "Post")
      expect(post_save.first.signatures).not_to be_empty

      post_find = index.resolve_method("find", "Post::<Class:Post>")
      expect(post_find.first.signatures).not_to be_empty

      index.delete(mongoid_path)
      index.delete(user_path)
      index.delete(post_path)
    end

    it "does not update signatures when Mongoid modules are not indexed" do
      # Index only a Mongoid model without Mongoid modules
      model_path = URI::Generic.from_path(path: "/fake_model.rb")
      index.index_single(model_path, <<~RUBY)
        class User
          include Mongoid::Document
        end
      RUBY

      # Verify save method exists with empty parameters
      entries = index.resolve_method("save", "User")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters).to be_empty

      # Mark indexing as complete
      index.instance_variable_set(:@initial_indexing_completed, true)

      # Activate addon
      addon.activate(global_state, outgoing_queue)

      # Wait for signature update attempt
      sleep(0.3)

      # Verify save method still has empty parameters (no Mongoid module to resolve from)
      entries = index.resolve_method("save", "User")
      expect(entries).not_to be_nil
      expect(entries.first.signatures).not_to be_empty
      expect(entries.first.signatures.first.parameters).to be_empty

      index.delete(model_path)
    end

    it "preserves DSL method signatures during core method signature updates" do
      # Index Mongoid module
      mongoid_path = URI::Generic.from_path(path: "/fake_mongoid.rb")
      index.index_single(mongoid_path, <<~RUBY)
        module Mongoid
          module Persistable
            module Savable
              def save(validate: true)
              end
            end
          end
        end
      RUBY

      # Index a Mongoid model with DSL methods
      model_path = URI::Generic.from_path(path: "/fake_model.rb")
      index.index_single(model_path, <<~RUBY)
        class User
          include Mongoid::Document
          field :name
          has_many :posts
        end
      RUBY

      # Verify DSL methods have proper signatures before update
      name_reader = index.resolve_method("name", "User")
      expect(name_reader.first.signatures.first.parameters).to be_empty

      name_writer = index.resolve_method("name=", "User")
      expect(name_writer.first.signatures.first.parameters.size).to eq(1)
      expect(name_writer.first.signatures.first.parameters.first).to be_a(RubyIndexer::Entry::RequiredParameter)

      posts_reader = index.resolve_method("posts", "User")
      expect(posts_reader.first.signatures.first.parameters).to be_empty

      # Mark indexing as complete and activate addon
      index.instance_variable_set(:@initial_indexing_completed, true)
      addon.activate(global_state, outgoing_queue)
      sleep(0.3)

      # Verify core method signatures are updated
      save_method = index.resolve_method("save", "User")
      expect(save_method.first.signatures).not_to be_empty
      expect(save_method.first.signatures.first.parameters.first.name).to eq(:validate)

      # Verify DSL method signatures are preserved
      name_reader_after = index.resolve_method("name", "User")
      expect(name_reader_after.first.signatures.first.parameters).to be_empty

      name_writer_after = index.resolve_method("name=", "User")
      expect(name_writer_after.first.signatures.first.parameters.size).to eq(1)
      expect(name_writer_after.first.signatures.first.parameters.first).to be_a(RubyIndexer::Entry::RequiredParameter)

      posts_reader_after = index.resolve_method("posts", "User")
      expect(posts_reader_after.first.signatures.first.parameters).to be_empty

      index.delete(mongoid_path)
      index.delete(model_path)
    end

    it "logs success message when signatures are updated" do
      # Index Mongoid module
      mongoid_path = URI::Generic.from_path(path: "/fake_mongoid.rb")
      index.index_single(mongoid_path, <<~RUBY)
        module Mongoid
          module Persistable
            module Savable
              def save(validate: true)
              end
            end
          end
        end
      RUBY

      # Index a Mongoid model
      model_path = URI::Generic.from_path(path: "/fake_model.rb")
      index.index_single(model_path, <<~RUBY)
        class User
          include Mongoid::Document
        end
      RUBY

      # Mark indexing as complete
      index.instance_variable_set(:@initial_indexing_completed, true)

      # Activate addon
      addon.activate(global_state, outgoing_queue)

      # Wait for signature update
      sleep(0.3)

      # Verify log messages
      expect(outgoing_queue.size).to be >= 2
      
      # Check activation message
      activation_msg = outgoing_queue.first
      expect(activation_msg).to be_a(RubyLsp::Notification)
      expect(activation_msg.params.message).to include("Activating Ruby LSP Mongoid add-on")
      
      # Check signature update message
      update_msg = outgoing_queue.last
      expect(update_msg).to be_a(RubyLsp::Notification)
      expect(update_msg.params.message).to match(/Updated \d+ method signatures from Mongoid modules/)

      index.delete(mongoid_path)
      index.delete(model_path)
    end
  end
end
