# frozen_string_literal: true

require "mongoid"

# Sample Mongoid model for testing ruby-lsp-mongoid indexing enhancement
class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # Basic field declarations
  field :name, type: String
  field :email, type: String
  field :age, type: Integer
  field :active, type: Boolean, default: true
  field :score, type: Float
  field :metadata, type: Hash
  field :tags, type: Array

  # Date/Time fields
  field :birthday, type: Date
  field :last_login_at, type: Time

  # Associations
  has_many :posts
  has_one :profile

  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  # Indexes
  index({ email: 1 }, { unique: true })
  index({ name: 1 })
end
