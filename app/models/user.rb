class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :books
  has_many :purchases_as_buyer, class_name: "Purchase", foreign_key: "buyer_id"
  has_many :purchases_as_seller, class_name: "Purchase", foreign_key: "seller_id"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
