require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
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
    post books_path, params: { book: { title: "Foo", author: "Bar"} }
    assert_response :success

    new_book = Book.last
    assert_not_nil new_book
    assert_equal new_book.title, "Foo"
    assert_equal new_book.author, "Bar"
    assert_equal new_book.user, @user
  end
end

