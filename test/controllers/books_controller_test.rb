require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:seller_one)
    login_as(@user)
  end

  def login_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect! if response.redirect?
  end

  test "GET /books/new renders the new book form" do
    get new_book_path
    assert_response :success

    assert_select "h1", text: "Add a New Book"
    assert_select "form[action='#{books_path}'][method='post']"
    assert_select "input[name='book[title]']"
    assert_select "input[name='book[author]']"
    assert_select "input[type='submit'][value='Create Book']"
  end

  test "POST /books with invalid data re-renders form with errors" do
    post books_path, params: { book: { title: "", author: "" } }
    assert_response :unprocessable_entity

    assert_select "h2", /prohibited this book from being saved/i
    assert_select "li", text: "Title can't be blank"
    assert_select "li", text: "Author can't be blank"
  end

  test "POST /books with valid data associates the book with the user" do
    post books_path, params: { book: { title: "Foo", author: "Bar", price: 12.99 } }

    # Should redirect to the user's library page
    assert_redirected_to user_path(@user.username)
    follow_redirect!
    assert_response :success

    # Verify we're on the user's library page
    assert_select "h1", text: "#{@user.username}'s Library"

    # Verify the book was created and associated with the user
    new_book = Book.last
    assert_not_nil new_book
    assert_equal "Foo", new_book.title
    assert_equal "Bar", new_book.author
    assert_equal @user, new_book.user
  end

  test "GET /books does not show books which are sold" do
    user_one = users(:seller_one)
    Book.create!(title: "Not Sold Book", author: "Bar", user_id: user_one.id, price: 10.00, sold: false)
    Book.create!(title: "Sold Book", author: "Bar", user_id: user_one.id, price: 10.00, sold: true)

    login_as(user_one)

    get books_path

    assert_select "p", text: "Not Sold Book"
    assert_not_select "p", text: "Sold Book"
  end

  test "GET /books does not show books which have a pending purchase" do
    seller = users(:seller_one)
    buyer = users(:buyer_one)
    Book.create!(id: 1, title: "Book", author: "Bar", user_id: seller.id, price: 10.00, sold: false)
    Purchase.create!(book_id: 1, buyer: buyer, seller: seller, status: "pending", amount_cents: 1000, platform_fee_cents: 100, seller_amount_cents: 900)

    login_as(seller)

    get books_path

    assert_not_select "p", text: "Book"
  end

  test "GET /books/new without Stripe account does not show book form" do
    @user.update!(stripe_account_id: nil) # Override fixture

    get new_book_path
    assert_response :success

    # Form should NOT be present
    assert_select "form[action='#{books_path}'][method='post']", count: 0
    assert_select "input[name='book[title]']", count: 0
  end

  test "GET /books/new without Stripe account shows payment setup prompt" do
    @user.update!(stripe_account_id: nil) # Override fixture

    get new_book_path
    assert_response :success

    # Should see message about needing Stripe
    assert_select "p", text: /Before you can list books for sale/i

    # Should see button to set up payments
    assert_select "form[action='#{user_stripe_connection_path(@user)}'][method='post']" do
      assert_select "button", text: "Set Up Payments"
    end
  end

  test "POST /books without Stripe account is rejected" do
    @user.update!(stripe_account_id: nil) # Override fixture

    post books_path, params: { book: { title: "Foo", author: "Bar", price: 12.99 } }

    # Should redirect to new_book_path (not create the book)
    assert_redirected_to new_book_path

    # Verify book was NOT created
    assert_equal 0, Book.where(title: "Foo").count
  end

  # Scan action tests
  test "GET /books/scan renders the scanning interface" do
    get scan_books_path
    assert_response :success

    assert_select "h1", text: "Add a Book"
    # Should show method selection options as links (inside turbo-frame)
    assert_select "a[href='#{scan_barcode_books_path}']", text: /Scan Barcode/
    assert_select "a[href='#{scan_photo_books_path}']", text: /Take Photo/
  end

  test "GET /books/scan without Stripe account shows payment setup prompt" do
    @user.update!(stripe_account_id: nil)

    get scan_books_path
    assert_response :success

    assert_select "p", text: /Before you can list books for sale/i
  end

  test "POST /books with scanned book data creates book with all fields" do
    post books_path, params: {
      book: {
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        price: 12.99,
        isbn_10: "0061120081",
        isbn_13: "9780061120084",
        description: "The unforgettable novel",
        cover_image_url: "https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg",
        publisher: "Harper Perennial",
        publication_year: 2006,
        page_count: 336,
        identified_by: "isbn"
      }
    }

    assert_redirected_to user_path(@user.username)

    book = Book.last
    assert_equal "To Kill a Mockingbird", book.title
    assert_equal "Harper Lee", book.author
    assert_equal "0061120081", book.isbn_10
    assert_equal "9780061120084", book.isbn_13
    assert_equal "Harper Perennial", book.publisher
    assert_equal 2006, book.publication_year
    assert_equal "isbn", book.identified_by
  end
end
