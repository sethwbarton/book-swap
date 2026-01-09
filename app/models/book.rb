class Book < ApplicationRecord
  validates :title, presence: true
  validates :author, presence: true
  validates :price, presence: true

  belongs_to :user
  has_many :purchases

  scope :available, -> { where(sold: false) }
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
