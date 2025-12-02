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

  describe "has_many DSL" do
    it "indexes has_many association methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          has_many :posts
        end
      RUBY

      assert_method_defined("posts", "User", 2)
      assert_method_defined("posts=", "User", 2)
      assert_method_defined("post_ids", "User", 2)
      assert_method_defined("post_ids=", "User", 2)
    end

    it "indexes has_many association methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Author
          has_many "articles"
        end
      RUBY

      assert_method_defined("articles", "Author", 2)
      assert_method_defined("articles=", "Author", 2)
      assert_method_defined("article_ids", "Author", 2)
      assert_method_defined("article_ids=", "Author", 2)
    end

    it "indexes multiple has_many associations" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          has_many :posts
          has_many :comments
        end
      RUBY

      assert_method_defined("posts", "User", 2)
      assert_method_defined("posts=", "User", 2)
      assert_method_defined("post_ids", "User", 2)
      assert_method_defined("post_ids=", "User", 2)
      assert_method_defined("comments", "User", 3)
      assert_method_defined("comments=", "User", 3)
      assert_method_defined("comment_ids", "User", 3)
      assert_method_defined("comment_ids=", "User", 3)
    end
  end

  describe "has_one DSL" do
    it "indexes has_one association methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          has_one :profile
        end
      RUBY

      assert_method_defined("profile", "User", 2)
      assert_method_defined("profile=", "User", 2)
      assert_method_defined("build_profile", "User", 2)
      assert_method_defined("create_profile", "User", 2)
      assert_method_defined("create_profile!", "User", 2)
    end

    it "indexes has_one association methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          has_one "account"
        end
      RUBY

      assert_method_defined("account", "User", 2)
      assert_method_defined("account=", "User", 2)
      assert_method_defined("build_account", "User", 2)
      assert_method_defined("create_account", "User", 2)
      assert_method_defined("create_account!", "User", 2)
    end
  end

  describe "belongs_to DSL" do
    it "indexes belongs_to association methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          belongs_to :author
        end
      RUBY

      assert_method_defined("author", "Post", 2)
      assert_method_defined("author=", "Post", 2)
      assert_method_defined("build_author", "Post", 2)
      assert_method_defined("create_author", "Post", 2)
      assert_method_defined("create_author!", "Post", 2)
    end

    it "indexes belongs_to association methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Comment
          belongs_to "post"
        end
      RUBY

      assert_method_defined("post", "Comment", 2)
      assert_method_defined("post=", "Comment", 2)
      assert_method_defined("build_post", "Comment", 2)
      assert_method_defined("create_post", "Comment", 2)
      assert_method_defined("create_post!", "Comment", 2)
    end
  end

  describe "has_and_belongs_to_many DSL" do
    it "indexes has_and_belongs_to_many association methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          has_and_belongs_to_many :tags
        end
      RUBY

      assert_method_defined("tags", "Post", 2)
      assert_method_defined("tags=", "Post", 2)
      assert_method_defined("tag_ids", "Post", 2)
      assert_method_defined("tag_ids=", "Post", 2)
    end

    it "indexes has_and_belongs_to_many association methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Article
          has_and_belongs_to_many "categories"
        end
      RUBY

      assert_method_defined("categories", "Article", 2)
      assert_method_defined("categories=", "Article", 2)
      assert_method_defined("category_ids", "Article", 2)
      assert_method_defined("category_ids=", "Article", 2)
    end
  end
end
