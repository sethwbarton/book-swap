class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end


# TODO: Want to list user's and their books that are for sale.