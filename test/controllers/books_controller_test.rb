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

  test "GET / shows all books from all users" do
    user_one = users(:seller_one)
    Book.create!(title: "The Only Book I Have", author: "Bar", user_id: user_one.id, price: 10.00)

    user_two = users(:seller_two)
    Book.create!(title: "Bar 1", author: "Bar", user_id: user_two.id, price: 15.00)
    Book.create!(title: "Bar 2", author: "Bar", user_id: user_two.id, price: 20.00)

    login_as(users(:seller_one))

    get root_path
    assert_response :success

    # Should see all books from all users
    assert_select "p", text: "Bar 1"
    assert_select "p", text: "Bar 2"
    assert_select "p", text: "The Only Book I Have"
  end
end
