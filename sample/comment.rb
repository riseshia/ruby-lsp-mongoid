# frozen_string_literal: true

require "mongoid"

# Sample embedded document for Post
class Comment
  include Mongoid::Document

  field :content, type: String
  field :author_name, type: String

  embedded_in :post
end
