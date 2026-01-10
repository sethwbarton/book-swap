require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "can create a book with title and author" do
    book = Book.create(title: "The Great Gatsby", author: "F. Scott Fitzgerald", price: 9.99, user: users(:seller_one))

    assert book.persisted?
    assert_equal "The Great Gatsby", book.title
    assert_equal "F. Scott Fitzgerald", book.author
  end

  test "can create a book with ISBN and identification fields" do
    book = Book.create(
      title: "To Kill a Mockingbird",
      author: "Harper Lee",
      price: 10.99,
      user: users(:seller_one),
      isbn_10: "0061120081",
      isbn_13: "9780061120084",
      description: "The unforgettable novel of a childhood in a sleepy Southern town",
      cover_image_url: "https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg",
      publisher: "Harper Perennial",
      publication_year: 2006,
      page_count: 336,
      identified_by: "isbn"
    )

    assert book.persisted?
    assert_equal "0061120081", book.isbn_10
    assert_equal "9780061120084", book.isbn_13
    assert_equal "Harper Perennial", book.publisher
    assert_equal 2006, book.publication_year
    assert_equal 336, book.page_count
    assert_equal "isbn", book.identified_by
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

  # Duplicate detection tests
  test "duplicate_for_user? returns true when user has book with same ISBN-13" do
    user = users(:seller_one)
    Book.create!(
      title: "Test Book",
      author: "Test Author",
      price: 10.00,
      user: user,
      isbn_13: "9780061120084"
    )

    assert Book.duplicate_for_user?(user, isbn_13: "9780061120084")
  end

  test "duplicate_for_user? returns true when user has book with same ISBN-10" do
    user = users(:seller_one)
    Book.create!(
      title: "Test Book",
      author: "Test Author",
      price: 10.00,
      user: user,
      isbn_10: "0061120081"
    )

    assert Book.duplicate_for_user?(user, isbn_10: "0061120081")
  end

  test "duplicate_for_user? returns true when matching either ISBN" do
    user = users(:seller_one)
    Book.create!(
      title: "Test Book",
      author: "Test Author",
      price: 10.00,
      user: user,
      isbn_10: "0061120081",
      isbn_13: "9780061120084"
    )

    # Match by ISBN-10
    assert Book.duplicate_for_user?(user, isbn_10: "0061120081")
    # Match by ISBN-13
    assert Book.duplicate_for_user?(user, isbn_13: "9780061120084")
    # Match by either
    assert Book.duplicate_for_user?(user, isbn_10: "0061120081", isbn_13: "9780061120084")
  end

  test "duplicate_for_user? returns false when user has no matching ISBN" do
    user = users(:seller_one)

    assert_not Book.duplicate_for_user?(user, isbn_13: "9780061120084")
  end

  test "duplicate_for_user? returns false when different user has the ISBN" do
    other_user = users(:seller_two)
    Book.create!(
      title: "Test Book",
      author: "Test Author",
      price: 10.00,
      user: other_user,
      isbn_13: "9780061120084"
    )

    user = users(:seller_one)
    assert_not Book.duplicate_for_user?(user, isbn_13: "9780061120084")
  end

  test "duplicate_for_user? returns false when no ISBNs provided" do
    user = users(:seller_one)

    assert_not Book.duplicate_for_user?(user, isbn_10: nil, isbn_13: nil)
  end

  test "find_duplicate_for_user returns the existing book" do
    user = users(:seller_one)
    existing_book = Book.create!(
      title: "Test Book",
      author: "Test Author",
      price: 10.00,
      user: user,
      isbn_13: "9780061120084"
    )

    found = Book.find_duplicate_for_user(user, isbn_13: "9780061120084")

    assert_equal existing_book, found
  end

  test "find_duplicate_for_user returns nil when no duplicate" do
    user = users(:seller_one)

    found = Book.find_duplicate_for_user(user, isbn_13: "9780061120084")

    assert_nil found
  end

  test "can attach condition photos" do
    book = books(:the_great_gatsby)

    assert_respond_to book, :condition_photos
    assert_equal 0, book.condition_photos.count
  end
end
