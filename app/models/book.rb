class Book < ApplicationRecord
  validates :title, presence: true
  validates :author, presence: true
  validates :price, presence: true

  belongs_to :user
  has_many :purchases

  # Condition photos for showing actual book state to buyers
  has_many_attached :condition_photos

  scope :available, -> {
    left_joins(:purchases)
      .where(sold: false)
      .where(purchases: { id: nil })
      .or(
        left_joins(:purchases)
          .where(sold: false)
          .where.not(purchases: { status: "pending" })
      )
      .distinct
  }
  scope :sold, -> { where(sold: true) }

  # Check if a user already has a book listed with the same ISBN
  def self.duplicate_for_user?(user, isbn_10: nil, isbn_13: nil)
    find_duplicate_for_user(user, isbn_10: isbn_10, isbn_13: isbn_13).present?
  end

  # Find an existing book for a user by ISBN
  def self.find_duplicate_for_user(user, isbn_10: nil, isbn_13: nil)
    return nil if isbn_10.blank? && isbn_13.blank?

    scope = user.books

    if isbn_10.present? && isbn_13.present?
      scope.where(isbn_10: isbn_10).or(scope.where(isbn_13: isbn_13)).first
    elsif isbn_10.present?
      scope.find_by(isbn_10: isbn_10)
    else
      scope.find_by(isbn_13: isbn_13)
    end
  end

  def available?
    !sold && !purchases.exists?(status: "pending")
  end

  def mark_as_sold!
    update!(sold: true)
  end

  def mark_as_available!
    update!(sold: false)
  end
end
