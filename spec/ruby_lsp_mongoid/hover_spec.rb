# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLsp::Mongoid::Hover do
  include RubyLsp::TestHelper

  let(:indexable_path) { URI::Generic.from_path(path: "/fake.rb") }

  def hover_on_source(source, position)
    with_server(source, stub_no_typechecker: true) do |server, uri|
      server.process_message(
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: position },
      )

      result = pop_result(server)
      result.response
    end
  end

  describe "field hover" do
    it "shows field with type option" do
      source = <<~RUBY
        class User
          field :name, type: String
        end
      RUBY

      response = hover_on_source(source, { line: 1, character: 9 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("type: String")
    end

    it "shows field with multiple options" do
      source = <<~RUBY
        class User
          field :active, type: Boolean, default: true
        end
      RUBY

      response = hover_on_source(source, { line: 1, character: 9 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("type: Boolean")
      expect(response.contents.value).to include("default: true")
    end
  end

  describe "association hover" do
    it "shows has_many association with linked class" do
      source = <<~RUBY
        class Post; end
        class User
          has_many :posts
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 12 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("has_many: [Post]")
    end

    it "shows has_many association with class_name option" do
      source = <<~RUBY
        class Comment; end
        class User
          has_many :replies, class_name: "Comment"
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 12 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("has_many: [Comment]")
    end

    it "shows has_many association without link when class not found" do
      source = <<~RUBY
        class User
          has_many :posts
        end
      RUBY

      response = hover_on_source(source, { line: 1, character: 12 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("has_many: Post")
      expect(response.contents.value).not_to include("[Post]")
    end

    it "shows has_one association with linked class" do
      source = <<~RUBY
        class Profile; end
        class User
          has_one :profile
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 11 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("has_one: [Profile]")
    end

    it "shows belongs_to association with linked class" do
      source = <<~RUBY
        class Author; end
        class Post
          belongs_to :author
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 14 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("belongs_to: [Author]")
    end

    it "shows has_and_belongs_to_many association with linked class" do
      source = <<~RUBY
        class Tag; end
        class Post
          has_and_belongs_to_many :tags
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 27 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("has_and_belongs_to_many: [Tag]")
    end
  end

  describe "embedded document hover" do
    it "shows embeds_many with linked class" do
      source = <<~RUBY
        class Comment; end
        class Post
          embeds_many :comments
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 15 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("embeds_many: [Comment]")
    end

    it "shows embeds_one with linked class" do
      source = <<~RUBY
        class AuthorInfo; end
        class Post
          embeds_one :author_info
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 14 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("embeds_one: [AuthorInfo]")
    end

    it "shows embedded_in with linked class" do
      source = <<~RUBY
        class Post; end
        class Comment
          embedded_in :post
        end
      RUBY

      response = hover_on_source(source, { line: 2, character: 15 })

      expect(response).not_to be_nil
      expect(response.contents.value).to include("embedded_in: [Post]")
    end
  end
end
