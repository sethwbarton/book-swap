require "test_helper"

class PurchaseTest < ActiveSupport::TestCase
  def setup
    @book = books(:the_great_gatsby)
    @buyer = users(:buyer_one)
    @seller = users(:seller_one)
  end

  test "valid purchase with all required fields" do
    purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    assert purchase.valid?
    assert purchase.save
  end

  test "calculates platform fee correctly (10%)" do
    amount_cents = 1000
    expected_fee = 100  # 10% of 1000
    expected_seller_amount = 900  # 90% of 1000

    fees = Purchase.calculate_fees(amount_cents)

    assert_equal expected_fee, fees[:platform_fee_cents]
    assert_equal expected_seller_amount, fees[:seller_amount_cents]
  end

  test "validates buyer cannot be seller" do
    purchase = Purchase.new(
      book: @book,
      buyer: @seller,  # Same as seller
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169
    )

    assert_not purchase.valid?
    assert_includes purchase.errors[:buyer_id], "cannot be the seller"
  end

  test "validates buyer cannot purchase same book twice - pending purchase exists" do
    # Create first purchase
    Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    # Try to create second purchase
    duplicate_purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169
    )

    assert_not duplicate_purchase.valid?
    assert_includes duplicate_purchase.errors[:buyer_id], "has already purchased this book"
  end

  test "validates buyer cannot purchase same book twice - completed purchase exists" do
    # Create completed purchase
    Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "completed"
    )

    # Try to create another purchase
    duplicate_purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169
    )

    assert_not duplicate_purchase.valid?
    assert_includes duplicate_purchase.errors[:buyer_id], "has already purchased this book"
  end

  test "allows new purchase if previous one was cancelled" do
    # Create cancelled purchase
    Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "cancelled"
    )

    # Should allow new purchase
    new_purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169
    )

    assert new_purchase.valid?
  end

  test "validates book must not already be sold" do
    sold_book = books(:to_kill_a_mockingbird)

    purchase = Purchase.new(
      book: sold_book,
      buyer: @buyer,
      seller: sold_book.user,
      amount_cents: 1099,
      platform_fee_cents: 110,
      seller_amount_cents: 989
    )

    assert_not purchase.valid?
    assert_includes purchase.errors[:book_id], "has already been sold"
  end

  test "validates status must be valid" do
    purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "invalid_status"
    )

    assert_not purchase.valid?
    assert_includes purchase.errors[:status], "is not included in the list"
  end

  test "validates amount_cents must be present and non-negative" do
    purchase = Purchase.new(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      platform_fee_cents: 130,
      seller_amount_cents: 1169
    )

    assert_not purchase.valid?
    assert_includes purchase.errors[:amount_cents], "can't be blank"
  end

  test "complete! marks purchase as completed and book as sold" do
    purchase = Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    assert_equal "pending", purchase.status
    assert_not @book.sold?

    purchase.complete!

    assert_equal "completed", purchase.status
    assert @book.reload.sold?
  end

  test "cancel! marks purchase as cancelled and book as available" do
    purchase = Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    purchase.cancel!

    assert_equal "cancelled", purchase.status
    assert_not_nil purchase.cancelled_at
    assert_not @book.reload.sold?
  end

  test "platform_fee_percentage returns configured value" do
    assert_equal 10, Purchase.platform_fee_percentage
  end
end
