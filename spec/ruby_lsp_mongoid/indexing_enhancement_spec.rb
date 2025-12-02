# frozen_string_literal: true

require "ruby_lsp/ruby_lsp_mongoid"
require "ruby_lsp/internal"

RSpec.describe RubyLsp::Mongoid::IndexingEnhancement do
  let(:index) { RubyIndexer::Index.new }
  let(:indexable_path) { URI::Generic.from_path(path: "/fake.rb") }

  after do
    index.delete(indexable_path)
  end

  def assert_method_defined(method_name, class_name, line)
    entries = index.resolve_method(method_name, class_name)
    expect(entries).not_to be_nil, "Expected method '#{method_name}' to be defined on '#{class_name}'"
    expect(entries.first.location.start_line).to eq(line)
  end

  describe "field DSL" do
    it "indexes field reader and writer methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          field :name
        end
      RUBY

      assert_method_defined("name", "User", 2)
      assert_method_defined("name=", "User", 2)
    end

    it "indexes field reader and writer methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          field "email"
        end
      RUBY

      assert_method_defined("email", "User", 2)
      assert_method_defined("email=", "User", 2)
    end

    it "indexes multiple fields" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          field :title
          field :content
          field :published_at
        end
      RUBY

      assert_method_defined("title", "Post", 2)
      assert_method_defined("title=", "Post", 2)
      assert_method_defined("content", "Post", 3)
      assert_method_defined("content=", "Post", 3)
      assert_method_defined("published_at", "Post", 4)
      assert_method_defined("published_at=", "Post", 4)
    end

    it "indexes fields with type option" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          field :age, type: Integer
          field :active, type: Boolean, default: false
        end
      RUBY

      assert_method_defined("age", "User", 2)
      assert_method_defined("age=", "User", 2)
      assert_method_defined("active", "User", 3)
      assert_method_defined("active=", "User", 3)
    end
  end
end
