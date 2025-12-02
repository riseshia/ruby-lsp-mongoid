# frozen_string_literal: true

require "mongoid"

# Sample Mongoid model demonstrating various DSL features
class Post
  include Mongoid::Document
  include Mongoid::Timestamps

  # Field declarations with different types
  field :title, type: String
  field :body, type: String
  field :slug, type: String
  field :published, type: Boolean, default: false
  field :view_count, type: Integer, default: 0
  field :published_at, type: DateTime

  # Embedded documents
  embeds_many :comments
  embeds_one :author_info

  # Relations
  belongs_to :user
  has_many :likes, class_name: "Like"
  has_and_belongs_to_many :categories

  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Validations
  validates :title, presence: true
  validates :body, presence: true
end

# Embedded document example
class Comment
  include Mongoid::Document

  field :content, type: String
  field :author_name, type: String

  embedded_in :post
end

class AuthorInfo
  include Mongoid::Document

  field :bio, type: String
  field :website, type: String

  embedded_in :post
end
