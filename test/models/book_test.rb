require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "can create a book with title and author" do
    book = Book.create(title: "The Great Gatsby", author: "F. Scott Fitzgerald")
    
    assert book.persisted?
    assert_equal "The Great Gatsby", book.title
    assert_equal "F. Scott Fitzgerald", book.author
  end
end

