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

    it "stores association type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Post; end
        class Comment; end
        class User
          has_many :posts
          has_many :replies, class_name: "Comment"
        end
      RUBY

      posts_entries = index.resolve_method("posts", "User")
      expect(posts_entries.first.comments).to eq("has_many: [Post](#{indexable_path}#L1)")

      replies_entries = index.resolve_method("replies", "User")
      expect(replies_entries.first.comments).to eq("has_many: [Comment](#{indexable_path}#L2)")
    end

    it "shows class name without link when class is not found" do
      index.index_single(indexable_path, <<~RUBY)
        class User
          has_many :posts
        end
      RUBY

      posts_entries = index.resolve_method("posts", "User")
      expect(posts_entries.first.comments).to eq("has_many: Post")
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

    it "stores association type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Profile; end
        class Account; end
        class User
          has_one :profile
          has_one :main_account, class_name: "Account"
        end
      RUBY

      profile_entries = index.resolve_method("profile", "User")
      expect(profile_entries.first.comments).to eq("has_one: [Profile](#{indexable_path}#L1)")

      main_account_entries = index.resolve_method("main_account", "User")
      expect(main_account_entries.first.comments).to eq("has_one: [Account](#{indexable_path}#L2)")
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

    it "stores association type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Author; end
        class User; end
        class Post
          belongs_to :author
          belongs_to :creator, class_name: "User"
        end
      RUBY

      author_entries = index.resolve_method("author", "Post")
      expect(author_entries.first.comments).to eq("belongs_to: [Author](#{indexable_path}#L1)")

      creator_entries = index.resolve_method("creator", "Post")
      expect(creator_entries.first.comments).to eq("belongs_to: [User](#{indexable_path}#L2)")
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

    it "stores association type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Tag; end
        class Category; end
        class Post
          has_and_belongs_to_many :tags
          has_and_belongs_to_many :topic_categories, class_name: "Category"
        end
      RUBY

      tags_entries = index.resolve_method("tags", "Post")
      expect(tags_entries.first.comments).to eq("has_and_belongs_to_many: [Tag](#{indexable_path}#L1)")

      topic_entries = index.resolve_method("topic_categories", "Post")
      expect(topic_entries.first.comments).to eq("has_and_belongs_to_many: [Category](#{indexable_path}#L2)")
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

    it "stores embedded type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Comment; end
        class Paragraph; end
        class Post
          embeds_many :comments
          embeds_many :sections, class_name: "Paragraph"
        end
      RUBY

      comments_entries = index.resolve_method("comments", "Post")
      expect(comments_entries.first.comments).to eq("embeds_many: [Comment](#{indexable_path}#L1)")

      sections_entries = index.resolve_method("sections", "Post")
      expect(sections_entries.first.comments).to eq("embeds_many: [Paragraph](#{indexable_path}#L2)")
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

    it "stores embedded type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class AuthorInfo; end
        class Profile; end
        class Post
          embeds_one :author_info
          embeds_one :details, class_name: "Profile"
        end
      RUBY

      author_info_entries = index.resolve_method("author_info", "Post")
      expect(author_info_entries.first.comments).to eq("embeds_one: [AuthorInfo](#{indexable_path}#L1)")

      details_entries = index.resolve_method("details", "Post")
      expect(details_entries.first.comments).to eq("embeds_one: [Profile](#{indexable_path}#L2)")
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

    it "stores embedded type and linked class in comments" do
      index.index_single(indexable_path, <<~RUBY)
        class Post; end
        class Article; end
        class Comment
          embedded_in :post
          embedded_in :article, class_name: "Article"
        end
      RUBY

      post_entries = index.resolve_method("post", "Comment")
      expect(post_entries.first.comments).to eq("embedded_in: [Post](#{indexable_path}#L1)")

      article_entries = index.resolve_method("article", "Comment")
      expect(article_entries.first.comments).to eq("embedded_in: [Article](#{indexable_path}#L2)")
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
end
