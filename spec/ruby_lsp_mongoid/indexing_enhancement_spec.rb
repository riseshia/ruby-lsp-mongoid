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

    it "stores field options in method comments for hover" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          field :age, type: Integer
          field :active, type: Boolean, default: false
          field :name, as: :n
          field :score, type: Float, as: :s, default: 0.0
          field :data
        end
      RUBY

      age_entries = index.resolve_method("age", "User")
      expect(age_entries.first.comments).to eq("type: Integer")

      active_entries = index.resolve_method("active", "User")
      expect(active_entries.first.comments).to eq("type: Boolean, default: false")

      name_entries = index.resolve_method("name", "User")
      expect(name_entries.first.comments).to eq("as: n")

      score_entries = index.resolve_method("score", "User")
      expect(score_entries.first.comments).to eq("type: Float, as: s, default: 0.0")

      # Field without options should have nil comments
      data_entries = index.resolve_method("data", "User")
      expect(data_entries.first.comments).to eq("")
    end

    it "indexes field with as: option for alias" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          field :name, as: :n
          field :email_address, type: String, as: :email
        end
      RUBY

      # Original name
      assert_method_defined("name", "User", 2)
      assert_method_defined("name=", "User", 2)
      # Alias
      assert_method_defined("n", "User", 2)
      assert_method_defined("n=", "User", 2)

      # Original name
      assert_method_defined("email_address", "User", 3)
      assert_method_defined("email_address=", "User", 3)
      # Alias
      assert_method_defined("email", "User", 3)
      assert_method_defined("email=", "User", 3)
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

  describe "embeds_many DSL" do
    it "indexes embeds_many methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          embeds_many :comments
        end
      RUBY

      assert_method_defined("comments", "Post", 2)
      assert_method_defined("comments=", "Post", 2)
    end

    it "indexes embeds_many methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Article
          embeds_many "paragraphs"
        end
      RUBY

      assert_method_defined("paragraphs", "Article", 2)
      assert_method_defined("paragraphs=", "Article", 2)
    end
  end

  describe "embeds_one DSL" do
    it "indexes embeds_one methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          embeds_one :author_info
        end
      RUBY

      assert_method_defined("author_info", "Post", 2)
      assert_method_defined("author_info=", "Post", 2)
      assert_method_defined("build_author_info", "Post", 2)
      assert_method_defined("create_author_info", "Post", 2)
      assert_method_defined("create_author_info!", "Post", 2)
    end

    it "indexes embeds_one methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          embeds_one "address"
        end
      RUBY

      assert_method_defined("address", "User", 2)
      assert_method_defined("address=", "User", 2)
      assert_method_defined("build_address", "User", 2)
      assert_method_defined("create_address", "User", 2)
      assert_method_defined("create_address!", "User", 2)
    end
  end

  describe "embedded_in DSL" do
    it "indexes embedded_in methods with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Comment
          embedded_in :post
        end
      RUBY

      assert_method_defined("post", "Comment", 2)
      assert_method_defined("post=", "Comment", 2)
    end

    it "indexes embedded_in methods with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Address
          embedded_in "user"
        end
      RUBY

      assert_method_defined("user", "Address", 2)
      assert_method_defined("user=", "Address", 2)
    end
  end

  describe "scope DSL" do
    def assert_singleton_method_defined(method_name, class_name, line)
      entries = index.resolve_method(method_name, class_name)
      expect(entries).not_to be_nil, "Expected singleton method '#{method_name}' to be defined on '#{class_name}'"
      expect(entries.first).to be_a(RubyIndexer::Entry::Method)
      expect(entries.first.location.start_line).to eq(line)
    end

    it "indexes scope as singleton method with symbol name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          scope :published, -> { where(published: true) }
        end
      RUBY

      assert_singleton_method_defined("published", "Post::<Class:Post>", 2)
    end

    it "indexes scope as singleton method with string name" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          scope "recent", -> { order(created_at: :desc) }
        end
      RUBY

      assert_singleton_method_defined("recent", "Post::<Class:Post>", 2)
    end

    it "indexes multiple scopes" do
      index.index_single(indexable_path, <<~RUBY)
        class Article
          scope :draft, -> { where(published: false) }
          scope :featured, -> { where(featured: true) }
        end
      RUBY

      assert_singleton_method_defined("draft", "Article::<Class:Article>", 2)
      assert_singleton_method_defined("featured", "Article::<Class:Article>", 3)
    end
  end

  describe "_id and id auto-indexing" do
    it "indexes _id and id when including Mongoid::Document" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
          field :name
        end
      RUBY

      assert_method_defined("_id", "User", 2)
      assert_method_defined("_id=", "User", 2)
      assert_method_defined("id", "User", 2)
      assert_method_defined("id=", "User", 2)
    end

    it "indexes _id and id only once when multiple DSL calls exist" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
          field :name
          field :email
          has_many :posts
        end
      RUBY

      # All _id/id methods should point to line 2 (include statement)
      entries = index.resolve_method("_id", "User")
      expect(entries.length).to eq(1)
      expect(entries.first.location.start_line).to eq(2)

      entries = index.resolve_method("id", "User")
      expect(entries.length).to eq(1)
      expect(entries.first.location.start_line).to eq(2)
    end

    it "indexes _id and id for association-only model" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
          has_many :posts
        end
      RUBY

      assert_method_defined("_id", "User", 2)
      assert_method_defined("_id=", "User", 2)
      assert_method_defined("id", "User", 2)
      assert_method_defined("id=", "User", 2)
    end

    it "indexes _id and id for scope-only model" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
          scope :active, -> { where(active: true) }
        end
      RUBY

      assert_method_defined("_id", "User", 2)
      assert_method_defined("_id=", "User", 2)
      assert_method_defined("id", "User", 2)
      assert_method_defined("id=", "User", 2)
    end

    it "indexes _id and id separately for multiple classes in same file" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
          field :name
        end

        class Post
          include Mongoid::Document
          field :title
        end
      RUBY

      # User has _id/id at line 2 (include statement)
      assert_method_defined("_id", "User", 2)
      assert_method_defined("id", "User", 2)

      # Post has its own _id/id at line 7 (include statement)
      assert_method_defined("_id", "Post", 7)
      assert_method_defined("id", "Post", 7)
    end
  end

  describe "Mongoid::Document inclusion" do
    def assert_singleton_method_defined(method_name, class_name, line)
      entries = index.resolve_method(method_name, class_name)
      expect(entries).not_to be_nil, "Expected singleton method '#{method_name}' to be defined on '#{class_name}'"
      expect(entries.first).to be_a(RubyIndexer::Entry::Method)
      expect(entries.first.location.start_line).to eq(line)
    end

    it "indexes core instance methods when including Mongoid::Document" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include Mongoid::Document
        end
      RUBY

      # Persistence methods
      assert_method_defined("save", "User", 2)
      assert_method_defined("save!", "User", 2)
      assert_method_defined("update", "User", 2)
      assert_method_defined("update!", "User", 2)
      assert_method_defined("destroy", "User", 2)
      assert_method_defined("delete", "User", 2)
      assert_method_defined("upsert", "User", 2)
      assert_method_defined("reload", "User", 2)

      # State methods
      assert_method_defined("new_record?", "User", 2)
      assert_method_defined("persisted?", "User", 2)
      assert_method_defined("valid?", "User", 2)
      assert_method_defined("changed?", "User", 2)

      # Attribute methods
      assert_method_defined("attributes", "User", 2)
      assert_method_defined("attributes=", "User", 2)
      assert_method_defined("assign_attributes", "User", 2)
      assert_method_defined("read_attribute", "User", 2)
      assert_method_defined("write_attribute", "User", 2)
      assert_method_defined("changes", "User", 2)
      assert_method_defined("errors", "User", 2)

      # Identity methods
      assert_method_defined("to_key", "User", 2)
      assert_method_defined("to_param", "User", 2)
      assert_method_defined("model_name", "User", 2)
      assert_method_defined("inspect", "User", 2)
    end

    it "indexes core class methods when including Mongoid::Document" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          include Mongoid::Document
        end
      RUBY

      # Query methods
      assert_singleton_method_defined("all", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("where", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("find", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("find_by", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("find_by!", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("first", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("last", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("count", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("exists?", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("distinct", "Post::<Class:Post>", 2)

      # Creation methods
      assert_singleton_method_defined("create", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("create!", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("new", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("build", "Post::<Class:Post>", 2)

      # Modification methods
      assert_singleton_method_defined("update_all", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("delete_all", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("destroy_all", "Post::<Class:Post>", 2)

      # Database methods
      assert_singleton_method_defined("collection", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("database", "Post::<Class:Post>", 2)
    end

    it "indexes both core methods and DSL methods together" do
      index.index_single(indexable_path, <<~RUBY)
        class Article
          include Mongoid::Document
          field :title
          has_many :comments
        end
      RUBY

      # Core instance methods from include
      assert_method_defined("save", "Article", 2)
      assert_method_defined("valid?", "Article", 2)

      # DSL field methods
      assert_method_defined("title", "Article", 3)
      assert_method_defined("title=", "Article", 3)

      # DSL association methods
      assert_method_defined("comments", "Article", 4)
      assert_method_defined("comments=", "Article", 4)

      # Core class methods from include
      assert_singleton_method_defined("all", "Article::<Class:Article>", 2)
      assert_singleton_method_defined("create", "Article::<Class:Article>", 2)
    end

    it "does not index core methods for non-Mongoid includes" do
      index.index_single(indexable_path, <<~RUBY)
        class MyClass
          include SomeOtherModule
        end
      RUBY

      entries = index.resolve_method("save", "MyClass")
      expect(entries).to be_nil
    end

    it "indexes core methods when including ApplicationDocument" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          include ApplicationDocument
        end
      RUBY

      # Core instance methods
      assert_method_defined("save", "User", 2)
      assert_method_defined("valid?", "User", 2)
      assert_method_defined("reload", "User", 2)

      # Core class methods
      assert_singleton_method_defined("all", "User::<Class:User>", 2)
      assert_singleton_method_defined("where", "User::<Class:User>", 2)
      assert_singleton_method_defined("create", "User::<Class:User>", 2)
    end

    it "indexes core methods for ApplicationDocument with DSL methods" do
      index.index_single(indexable_path, <<~RUBY)
        class Post
          include ApplicationDocument
          field :title
          scope :published, -> { where(published: true) }
        end
      RUBY

      # Core instance methods from ApplicationDocument
      assert_method_defined("save", "Post", 2)
      assert_method_defined("update", "Post", 2)

      # DSL field methods
      assert_method_defined("title", "Post", 3)
      assert_method_defined("title=", "Post", 3)

      # Core class methods from ApplicationDocument
      assert_singleton_method_defined("find", "Post::<Class:Post>", 2)
      assert_singleton_method_defined("create", "Post::<Class:Post>", 2)

      # DSL scope methods
      assert_singleton_method_defined("published", "Post::<Class:Post>", 4)
    end
  end

  describe "method signatures" do
    def get_method_signatures(method_name, class_name)
      entries = index.resolve_method(method_name, class_name)
      return nil unless entries&.any?

      entries.first.signatures
    end

    describe "field DSL signatures" do
      it "registers reader with empty signature" do
        index.index_single(indexable_path, <<~RUBY)
          class User
            field :name
          end
        RUBY

        signatures = get_method_signatures("name", "User")
        expect(signatures).not_to be_nil
        expect(signatures.first.parameters).to be_empty
      end

      it "registers writer with required value parameter" do
        index.index_single(indexable_path, <<~RUBY)
          class User
            field :name
          end
        RUBY

        signatures = get_method_signatures("name=", "User")
        expect(signatures).not_to be_nil
        expect(signatures.first.parameters.size).to eq(1)
        expect(signatures.first.parameters.first).to be_a(RubyIndexer::Entry::RequiredParameter)
        expect(signatures.first.parameters.first.name).to eq(:value)
      end
    end

    describe "association DSL signatures" do
      it "registers has_many reader with empty signature" do
        index.index_single(indexable_path, <<~RUBY)
          class User
            has_many :posts
          end
        RUBY

        signatures = get_method_signatures("posts", "User")
        expect(signatures.first.parameters).to be_empty
      end

      it "registers has_many writer with required parameter" do
        index.index_single(indexable_path, <<~RUBY)
          class User
            has_many :posts
          end
        RUBY

        signatures = get_method_signatures("posts=", "User")
        expect(signatures.first.parameters.size).to eq(1)
        expect(signatures.first.parameters.first).to be_a(RubyIndexer::Entry::RequiredParameter)
      end

      it "registers builder methods with optional attributes parameter" do
        index.index_single(indexable_path, <<~RUBY)
          class User
            has_one :profile
          end
        RUBY

        %w[build_profile create_profile create_profile!].each do |method_name|
          signatures = get_method_signatures(method_name, "User")
          expect(signatures).not_to be_nil, "Expected #{method_name} to have signatures"
          expect(signatures.first.parameters.size).to eq(1)
          expect(signatures.first.parameters.first).to be_a(RubyIndexer::Entry::OptionalParameter)
          expect(signatures.first.parameters.first.name).to eq(:attributes)
        end
      end
    end

    describe "scope DSL signatures" do
      it "registers scope without parameters when lambda has no params" do
        index.index_single(indexable_path, <<~RUBY)
          class Post
            scope :published, -> { where(published: true) }
          end
        RUBY

        entries = index.resolve_method("published", "Post::<Class:Post>")
        expect(entries).not_to be_nil
        expect(entries.first.signatures.first.parameters).to be_empty
      end

      it "registers scope with required parameters from lambda" do
        index.index_single(indexable_path, <<~RUBY)
          class Post
            scope :by_author, ->(author_id) { where(author_id: author_id) }
          end
        RUBY

        entries = index.resolve_method("by_author", "Post::<Class:Post>")
        expect(entries).not_to be_nil
        params = entries.first.signatures.first.parameters
        expect(params.size).to eq(1)
        expect(params.first).to be_a(RubyIndexer::Entry::RequiredParameter)
        expect(params.first.name).to eq(:author_id)
      end

      it "registers scope with optional parameters from lambda" do
        index.index_single(indexable_path, <<~RUBY)
          class Post
            scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }
          end
        RUBY

        entries = index.resolve_method("recent", "Post::<Class:Post>")
        expect(entries).not_to be_nil
        params = entries.first.signatures.first.parameters
        expect(params.size).to eq(1)
        expect(params.first).to be_a(RubyIndexer::Entry::OptionalParameter)
        expect(params.first.name).to eq(:limit)
      end

      it "registers scope with multiple parameters from lambda" do
        index.index_single(indexable_path, <<~RUBY)
          class Post
            scope :between_dates, ->(start_date, end_date) { where(created_at: start_date..end_date) }
          end
        RUBY

        entries = index.resolve_method("between_dates", "Post::<Class:Post>")
        expect(entries).not_to be_nil
        params = entries.first.signatures.first.parameters
        expect(params.size).to eq(2)
        expect(params[0].name).to eq(:start_date)
        expect(params[1].name).to eq(:end_date)
      end

      it "registers scope with keyword parameters from lambda" do
        index.index_single(indexable_path, <<~RUBY)
          class Post
            scope :filtered, ->(status:, category: nil) { where(status: status, category: category) }
          end
        RUBY

        entries = index.resolve_method("filtered", "Post::<Class:Post>")
        expect(entries).not_to be_nil
        params = entries.first.signatures.first.parameters
        expect(params.size).to eq(2)
        expect(params[0]).to be_a(RubyIndexer::Entry::KeywordParameter)
        expect(params[0].name).to eq(:status)
        expect(params[1]).to be_a(RubyIndexer::Entry::OptionalKeywordParameter)
        expect(params[1].name).to eq(:category)
      end
    end
  end
end
