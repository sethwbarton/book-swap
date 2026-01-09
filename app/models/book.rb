class Book < ApplicationRecord
  validates :title, presence: true
  validates :author, presence: true
  validates :price, presence: true

  belongs_to :user
  has_many :purchases

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

  def available?
    !sold
  end

  def mark_as_sold!
    update!(sold: true)
  end

  def mark_as_available!
    update!(sold: false)
  end
end
