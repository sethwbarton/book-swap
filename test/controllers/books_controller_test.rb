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
    post books_path, params: { book: { title: "Foo", author: "Bar" } }
    follow_redirect! if response.redirect?
    assert_response :success

    new_book = Book.last
    assert_not_nil new_book
    assert_equal new_book.title, "Foo"
    assert_equal new_book.author, "Bar"
    assert_equal new_book.user, @user
  end

  test "GET /books only shows books associated with the user" do
    login_as(users(:two))

    post books_path, params: { book: { title: "A Shade Darker", author: "Simon Barr" } }
    post books_path, params: { book: { title: "Purple Watermelon Man", author: "Joe Jackson" } }
    post books_path, params: { book: { title: "Limp Ballon", author: "Stephanie Briggs" } }

    login_as(users(:one))

    post books_path, params: { book: { title: "The Only Book I Have", author: "Stephen King" } }
    follow_redirect! if response.redirect?
    assert_response :success

    # Visit the books listing (show action) and assert only user's books appear
    get root_path
    assert_response :success

    # User two's titles should not be present
    assert_dom "p", { text: "A Shade Darker", count: 0 }
    assert_dom "p", { text: "Purple Watermelon Man", count: 0 }
    assert_dom "p", { text: "Limp Balloon", count: 0 }

    # User one's title should be present
    assert_select "p", { text: "The Only Book I Have", count: 1 }
  end
end
