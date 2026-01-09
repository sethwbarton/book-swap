class Purchase < ApplicationRecord
  belongs_to :book
  belongs_to :buyer, class_name: "User"
  belongs_to :seller, class_name: "User"

  validates :status, inclusion: { in: %w[pending completed cancelled] }
  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :platform_fee_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :seller_amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :buyer_cannot_be_seller
  validate :buyer_cannot_purchase_same_book_twice
  validate :book_must_not_be_sold

  def self.platform_fee_percentage
    Rails.application.config.platform_fee_percentage
  end

  def self.calculate_fees(amount_cents)
    platform_fee_cents = (amount_cents * platform_fee_percentage / 100.0).round
    seller_amount_cents = amount_cents - platform_fee_cents

    {
      platform_fee_cents: platform_fee_cents,
      seller_amount_cents: seller_amount_cents
    }
  end

  def complete!
    transaction do
      update!(status: "completed")
      book.mark_as_sold!
    end
  end

  def cancel!
    transaction do
      update!(status: "cancelled", cancelled_at: Time.current)
      book.mark_as_available!
    end
  end

  private

  def buyer_cannot_be_seller
    if buyer_id == seller_id
      errors.add(:buyer_id, "cannot be the seller")
    end
  end

  def buyer_cannot_purchase_same_book_twice
    existing_purchase = Purchase.where(
      book_id: book_id,
      buyer_id: buyer_id
    ).where(status: [ "pending", "completed" ]).where.not(id: id).first

    if existing_purchase
      errors.add(:buyer_id, "has already purchased this book")
    end
  end

  def book_must_not_be_sold
    if book&.sold?
      errors.add(:book_id, "has already been sold")
    end
  end
end
