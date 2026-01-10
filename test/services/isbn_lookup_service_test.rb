require "test_helper"
require "mocha/minitest"

class IsbnLookupServiceTest < ActiveSupport::TestCase
  test "lookup returns book data from Open Library for valid ISBN-13" do
    isbn = "9780061120084"
    open_library_response = {
      "title" => "To Kill a Mockingbird",
      "authors" => [ { "key" => "/authors/OL498979A" } ],
      "publishers" => [ "Harper Perennial Modern Classics" ],
      "publish_date" => "2006",
      "number_of_pages" => 336,
      "isbn_10" => [ "0061120081" ],
      "isbn_13" => [ "9780061120084" ],
      "description" => { "value" => "The unforgettable novel of a childhood in a sleepy Southern town" }
    }.to_json

    author_response = {
      "name" => "Harper Lee"
    }.to_json

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 200, body: open_library_response)

    stub_request(:get, "https://openlibrary.org/authors/OL498979A.json")
      .to_return(status: 200, body: author_response)

    result = IsbnLookupService.lookup(isbn)

    assert_not_nil result
    assert_equal "To Kill a Mockingbird", result[:title]
    assert_equal "Harper Lee", result[:author]
    assert_equal "0061120081", result[:isbn_10]
    assert_equal "9780061120084", result[:isbn_13]
    assert_equal "Harper Perennial Modern Classics", result[:publisher]
    assert_equal 2006, result[:publication_year]
    assert_equal 336, result[:page_count]
    assert_includes result[:cover_image_url], "9780061120084"
  end

  test "lookup returns book data from Open Library for valid ISBN-10" do
    isbn = "0061120081"
    open_library_response = {
      "title" => "To Kill a Mockingbird",
      "authors" => [ { "key" => "/authors/OL498979A" } ],
      "publishers" => [ "Harper Perennial" ],
      "publish_date" => "2006",
      "number_of_pages" => 336,
      "isbn_10" => [ "0061120081" ],
      "isbn_13" => [ "9780061120084" ]
    }.to_json

    author_response = {
      "name" => "Harper Lee"
    }.to_json

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 200, body: open_library_response)

    stub_request(:get, "https://openlibrary.org/authors/OL498979A.json")
      .to_return(status: 200, body: author_response)

    result = IsbnLookupService.lookup(isbn)

    assert_not_nil result
    assert_equal "To Kill a Mockingbird", result[:title]
    assert_equal "Harper Lee", result[:author]
  end

  test "lookup normalizes ISBN by removing dashes" do
    isbn_with_dashes = "978-0-06-112008-4"
    normalized_isbn = "9780061120084"

    open_library_response = {
      "title" => "To Kill a Mockingbird",
      "authors" => [ { "key" => "/authors/OL498979A" } ],
      "publishers" => [ "Harper Perennial" ],
      "publish_date" => "2006"
    }.to_json

    author_response = { "name" => "Harper Lee" }.to_json

    stub_request(:get, "https://openlibrary.org/isbn/#{normalized_isbn}.json")
      .to_return(status: 200, body: open_library_response)

    stub_request(:get, "https://openlibrary.org/authors/OL498979A.json")
      .to_return(status: 200, body: author_response)

    result = IsbnLookupService.lookup(isbn_with_dashes)

    assert_not_nil result
    assert_equal "To Kill a Mockingbird", result[:title]
  end

  test "lookup falls back to Google Books when Open Library returns 404" do
    isbn = "9780061120084"

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 404)

    google_books_response = {
      "totalItems" => 1,
      "items" => [ {
        "volumeInfo" => {
          "title" => "To Kill a Mockingbird",
          "authors" => [ "Harper Lee" ],
          "publisher" => "Harper Perennial",
          "publishedDate" => "2006-05-23",
          "pageCount" => 336,
          "description" => "The unforgettable novel",
          "industryIdentifiers" => [
            { "type" => "ISBN_10", "identifier" => "0061120081" },
            { "type" => "ISBN_13", "identifier" => "9780061120084" }
          ],
          "imageLinks" => {
            "thumbnail" => "http://books.google.com/books/content?id=PGR2AwAAQBAJ&printsec=frontcover&img=1&zoom=1"
          }
        }
      } ]
    }.to_json

    stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
      .with(query: hash_including(q: "isbn:#{isbn}"))
      .to_return(status: 200, body: google_books_response)

    result = IsbnLookupService.lookup(isbn)

    assert_not_nil result
    assert_equal "To Kill a Mockingbird", result[:title]
    assert_equal "Harper Lee", result[:author]
    assert_equal "Harper Perennial", result[:publisher]
    assert_equal 2006, result[:publication_year]
  end

  test "lookup returns nil when ISBN not found in any service" do
    isbn = "0000000000000"

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 404)

    stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
      .with(query: hash_including(q: "isbn:#{isbn}"))
      .to_return(status: 200, body: { "totalItems" => 0 }.to_json)

    result = IsbnLookupService.lookup(isbn)

    assert_nil result
  end

  test "lookup returns nil for invalid ISBN format" do
    result = IsbnLookupService.lookup("invalid")

    assert_nil result
  end

  test "lookup handles Open Library network errors gracefully" do
    isbn = "9780061120084"

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_timeout

    google_books_response = {
      "totalItems" => 1,
      "items" => [ {
        "volumeInfo" => {
          "title" => "To Kill a Mockingbird",
          "authors" => [ "Harper Lee" ]
        }
      } ]
    }.to_json

    stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
      .with(query: hash_including(q: "isbn:#{isbn}"))
      .to_return(status: 200, body: google_books_response)

    result = IsbnLookupService.lookup(isbn)

    assert_not_nil result
    assert_equal "To Kill a Mockingbird", result[:title]
  end

  test "lookup extracts publication year from various date formats" do
    isbn = "9780061120084"

    # Test with just a year
    open_library_response = {
      "title" => "Test Book",
      "publish_date" => "2006"
    }.to_json

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 200, body: open_library_response)

    result = IsbnLookupService.lookup(isbn)

    assert_equal 2006, result[:publication_year]
  end

  test "lookup handles description as string" do
    isbn = "9780061120084"

    open_library_response = {
      "title" => "Test Book",
      "description" => "A simple string description"
    }.to_json

    stub_request(:get, "https://openlibrary.org/isbn/#{isbn}.json")
      .to_return(status: 200, body: open_library_response)

    result = IsbnLookupService.lookup(isbn)

    assert_equal "A simple string description", result[:description]
  end
end
