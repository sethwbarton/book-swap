require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "can create a book with title and author" do
    book = Book.create(title: "The Great Gatsby", author: "F. Scott Fitzgerald", price: 9.99, user: users(:seller_one))

    assert book.persisted?
    assert_equal "The Great Gatsby", book.title
    assert_equal "F. Scott Fitzgerald", book.author
  end

  test "available? returns true when not sold" do
    book = books(:the_great_gatsby)

    assert book.available?
    assert_not book.sold?
  end

  test "available? returns false when sold" do
    book = books(:to_kill_a_mockingbird)

    assert_not book.available?
    assert book.sold?
  end

  test "available? returns false when book has pending purchase" do
    book = books(:the_great_gatsby)
    Purchase.create!(
      book: book,
      buyer: users(:buyer_one),
      seller: book.user,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    assert_not book.available?
  end

  test "available? returns true when book has cancelled purchase" do
    book = books(:the_great_gatsby)
    Purchase.create!(
      book: book,
      buyer: users(:buyer_one),
      seller: book.user,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "cancelled"
    )

    assert book.available?
  end

  test "mark_as_sold! updates sold to true" do
    book = books(:the_great_gatsby)

    assert_not book.sold?

    book.mark_as_sold!

    assert book.reload.sold?
  end

  test "mark_as_available! updates sold to false" do
    book = books(:to_kill_a_mockingbird)

    assert book.sold?

    book.mark_as_available!

    assert_not book.reload.sold?
  end

  test "scope available returns only unsold books" do
    available_books = Book.available

    assert_includes available_books, books(:the_great_gatsby)
    assert_includes available_books, books(:nineteen_eighty_four)
    assert_not_includes available_books, books(:to_kill_a_mockingbird)
  end

  test "scope available excludes books with pending purchases" do
    book = books(:the_great_gatsby)
    Purchase.create!(
      book: book,
      buyer: users(:buyer_one),
      seller: book.user,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending"
    )

    assert_not_includes Book.available, book
  end

  test "scope available includes books with cancelled purchases" do
    book = books(:the_great_gatsby)
    Purchase.create!(
      book: book,
      buyer: users(:buyer_one),
      seller: book.user,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "cancelled"
    )

    assert_includes Book.available, book
  end

  test "scope sold returns only sold books" do
    sold_books = Book.sold

    assert_includes sold_books, books(:to_kill_a_mockingbird)
    assert_not_includes sold_books, books(:the_great_gatsby)
    assert_not_includes sold_books, books(:nineteen_eighty_four)
  end

  test "has_many purchases association" do
    book = books(:the_great_gatsby)

    assert_respond_to book, :purchases
  end
end
