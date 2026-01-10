require "test_helper"
require "mocha/minitest"

class BookImageRecognitionServiceTest < ActiveSupport::TestCase
  def setup
    @sample_image = StringIO.new("fake image data")
  end

  test "identify extracts text and returns book matches" do
    extracted_text = "TO KILL A MOCKINGBIRD\nHARPER LEE\nA Novel"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    google_books_response = {
      "totalItems" => 2,
      "items" => [
        {
          "volumeInfo" => {
            "title" => "To Kill a Mockingbird",
            "authors" => [ "Harper Lee" ],
            "publisher" => "Harper Perennial",
            "publishedDate" => "2006",
            "industryIdentifiers" => [
              { "type" => "ISBN_13", "identifier" => "9780061120084" }
            ],
            "imageLinks" => { "thumbnail" => "http://books.google.com/image1.jpg" }
          }
        },
        {
          "volumeInfo" => {
            "title" => "Go Set a Watchman",
            "authors" => [ "Harper Lee" ],
            "publisher" => "HarperCollins",
            "publishedDate" => "2015",
            "industryIdentifiers" => [
              { "type" => "ISBN_13", "identifier" => "9780062409850" }
            ],
            "imageLinks" => { "thumbnail" => "http://books.google.com/image2.jpg" }
          }
        }
      ]
    }.to_json

    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: google_books_response)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_not_nil results
    assert results.is_a?(Array)
    assert_equal 2, results.length
    assert_equal "To Kill a Mockingbird", results.first[:title]
    assert_equal "Harper Lee", results.first[:author]
  end

  test "identify returns empty array when no text detected" do
    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(nil)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_equal [], results
  end

  test "identify returns empty array when no books found for extracted text" do
    extracted_text = "RANDOM GIBBERISH TEXT"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: { "totalItems" => 0 }.to_json)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_equal [], results
  end

  test "identify limits results to 5 matches" do
    extracted_text = "HARRY POTTER"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    # Return 10 items
    items = 10.times.map do |i|
      {
        "volumeInfo" => {
          "title" => "Harry Potter Book #{i + 1}",
          "authors" => [ "J.K. Rowling" ]
        }
      }
    end

    google_books_response = { "totalItems" => 10, "items" => items }.to_json

    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: google_books_response)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_equal 5, results.length
  end

  test "identify handles Vision API errors gracefully" do
    mock_vision_client = mock("vision_client")
    mock_vision_client.stubs(:text_detection).raises(Google::Cloud::Error.new("API Error"))

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_equal [], results
  end

  test "identify cleans and formats extracted text for search" do
    # Text with lots of noise that should be cleaned
    extracted_text = "THE GREAT GATSBY\n\nF. SCOTT FITZGERALD\n\n$14.99\nISBN 978-0-7432-7356-5"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    google_books_response = {
      "totalItems" => 1,
      "items" => [ {
        "volumeInfo" => {
          "title" => "The Great Gatsby",
          "authors" => [ "F. Scott Fitzgerald" ]
        }
      } ]
    }.to_json

    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: google_books_response)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_equal 1, results.length
    assert_equal "The Great Gatsby", results.first[:title]
  end

  test "identify accepts file path as input" do
    extracted_text = "TEST BOOK TITLE"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: { "totalItems" => 0 }.to_json)

    # Should not raise an error when passed a file path string
    results = BookImageRecognitionService.identify("/path/to/image.jpg")

    assert results.is_a?(Array)
  end

  test "identify extracts ISBN from image text and looks it up directly" do
    # When OCR detects an ISBN in the image, use it directly
    extracted_text = "TO KILL A MOCKINGBIRD\nISBN: 978-0-06-112008-4"

    mock_vision_client = mock("vision_client")
    mock_response = mock("response")
    mock_annotation = mock("annotation")

    mock_annotation.stubs(:text).returns(extracted_text)
    mock_response.stubs(:responses).returns([ mock_annotation ])
    mock_vision_client.stubs(:text_detection).returns(mock_response)

    Google::Cloud::Vision.stubs(:image_annotator).returns(mock_vision_client)

    # Mock the ISBN lookup to return a result
    IsbnLookupService.stubs(:lookup).with("9780061120084").returns({
      title: "To Kill a Mockingbird",
      author: "Harper Lee",
      isbn_13: "9780061120084",
      publisher: "Harper Perennial",
      publication_year: 2006,
      cover_image_url: "https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg"
    })

    # Text search fallback (shouldn't be needed if ISBN found)
    stub_request(:get, /www\.googleapis\.com\/books\/v1\/volumes/)
      .to_return(status: 200, body: { "totalItems" => 0 }.to_json)

    results = BookImageRecognitionService.identify(@sample_image)

    assert_not_empty results
    assert_equal "To Kill a Mockingbird", results.first[:title]
  end
end
