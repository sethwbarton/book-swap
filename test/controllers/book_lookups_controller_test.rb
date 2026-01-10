require "test_helper"
require "mocha/minitest"

class BookLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:seller_one)
    login_as(@user)
  end

  # === ISBN Lookup Tests ===

  test "POST /book_lookups/isbn returns book data for valid ISBN" do
    isbn = "9780061120084"
    book_data = {
      title: "To Kill a Mockingbird",
      author: "Harper Lee",
      isbn_10: "0061120081",
      isbn_13: "9780061120084",
      publisher: "Harper Perennial",
      publication_year: 2006,
      page_count: 336,
      cover_image_url: "https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg",
      description: "The unforgettable novel"
    }

    IsbnLookupService.stubs(:lookup).with(isbn).returns(book_data)

    post book_lookups_isbn_path, params: { isbn: isbn }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "To Kill a Mockingbird", json["title"]
    assert_equal "Harper Lee", json["author"]
    assert_equal "9780061120084", json["isbn_13"]
    assert_equal "Harper Perennial", json["publisher"]
    assert_equal 2006, json["publication_year"]
  end

  test "POST /book_lookups/isbn returns not_found error for unknown ISBN" do
    isbn = "0000000000000"

    IsbnLookupService.stubs(:lookup).with(isbn).returns(nil)

    post book_lookups_isbn_path, params: { isbn: isbn }, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)

    assert_equal "not_found", json["error"]
    assert_equal "No book found for this ISBN", json["message"]
  end

  test "POST /book_lookups/isbn returns error for missing ISBN param" do
    post book_lookups_isbn_path, params: {}, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_equal "invalid_request", json["error"]
    assert_equal "ISBN is required", json["message"]
  end

  test "POST /book_lookups/isbn requires authentication" do
    delete session_path # Log out

    post book_lookups_isbn_path, params: { isbn: "9780061120084" }, as: :json

    assert_response :redirect
  end

  test "POST /book_lookups/isbn includes duplicate warning when user already has ISBN" do
    isbn = "9780061120084"

    # Create an existing book for this user with this ISBN
    existing_book = Book.create!(
      title: "Existing Book",
      author: "Test Author",
      price: 10.00,
      user: @user,
      isbn_13: isbn
    )

    book_data = {
      title: "To Kill a Mockingbird",
      author: "Harper Lee",
      isbn_10: "0061120081",
      isbn_13: isbn,
      publisher: "Harper Perennial",
      publication_year: 2006
    }

    IsbnLookupService.stubs(:lookup).with(isbn).returns(book_data)

    post book_lookups_isbn_path, params: { isbn: isbn }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal true, json["duplicate"]
    assert_equal existing_book.id, json["existing_book_id"]
    assert_equal "You already have this book listed", json["duplicate_message"]
  end

  test "POST /book_lookups/isbn does not include duplicate warning for new ISBN" do
    isbn = "9780061120084"

    book_data = {
      title: "To Kill a Mockingbird",
      author: "Harper Lee",
      isbn_10: "0061120081",
      isbn_13: isbn
    }

    IsbnLookupService.stubs(:lookup).with(isbn).returns(book_data)

    post book_lookups_isbn_path, params: { isbn: isbn }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal false, json["duplicate"]
    assert_nil json["existing_book_id"]
  end

  # === Image Lookup Tests ===

  test "POST /book_lookups/image returns matches for uploaded image" do
    matches = [
      {
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        isbn_13: "9780061120084",
        cover_image_url: "http://books.google.com/image.jpg"
      },
      {
        title: "Go Set a Watchman",
        author: "Harper Lee",
        isbn_13: "9780062409850",
        cover_image_url: "http://books.google.com/image2.jpg"
      }
    ]

    BookImageRecognitionService.stubs(:identify).returns(matches)

    # Create a fake uploaded file
    image = fixture_file_upload("test_book_cover.jpg", "image/jpeg")

    post book_lookups_image_path, params: { image: image }

    assert_response :success
    json = JSON.parse(response.body)

    assert json["matches"].is_a?(Array)
    assert_equal 2, json["matches"].length
    assert_equal "To Kill a Mockingbird", json["matches"].first["title"]
  end

  test "POST /book_lookups/image returns empty matches when no books identified" do
    BookImageRecognitionService.stubs(:identify).returns([])

    image = fixture_file_upload("test_book_cover.jpg", "image/jpeg")

    post book_lookups_image_path, params: { image: image }

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal [], json["matches"]
    assert_equal "No books identified from image", json["message"]
  end

  test "POST /book_lookups/image returns error for missing image param" do
    post book_lookups_image_path, params: {}, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_equal "invalid_request", json["error"]
    assert_equal "Image is required", json["message"]
  end

  test "POST /book_lookups/image requires authentication" do
    delete session_path # Log out

    image = fixture_file_upload("test_book_cover.jpg", "image/jpeg")

    post book_lookups_image_path, params: { image: image }

    assert_response :redirect
  end

  test "POST /book_lookups/image includes duplicate flag for matching books" do
    # Create an existing book for this user
    Book.create!(
      title: "Existing Book",
      author: "Test Author",
      price: 10.00,
      user: @user,
      isbn_13: "9780061120084"
    )

    matches = [
      {
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        isbn_13: "9780061120084"  # Same ISBN as existing book
      },
      {
        title: "Go Set a Watchman",
        author: "Harper Lee",
        isbn_13: "9780062409850"  # Different ISBN
      }
    ]

    BookImageRecognitionService.stubs(:identify).returns(matches)

    image = fixture_file_upload("test_book_cover.jpg", "image/jpeg")

    post book_lookups_image_path, params: { image: image }

    assert_response :success
    json = JSON.parse(response.body)

    # First match should be marked as duplicate
    assert_equal true, json["matches"].first["duplicate"]
    # Second match should not be marked as duplicate
    assert_equal false, json["matches"].second["duplicate"]
  end

  private

  def login_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect! if response.redirect?
  end
end
