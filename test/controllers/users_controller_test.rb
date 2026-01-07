require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:seller_one)
    login_as(@user)
  end

  def login_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect! if response.redirect?
  end

  test "GET /users shows all users with links to username-based paths" do
    get users_path
    assert_response :success

    # Verify that links use username, not id
    @users = User.all
    @users.each do |user|
      assert_select "a[href='#{user_path(user.username)}']"
    end
  end

  test "GET /users/:username shows the user's library" do
    user = users(:seller_two)
    Book.create!(title: "Test Book", author: "Test Author", price: 9.99, user: user)

    get user_path(user.username)
    assert_response :success

    assert_select "h1", text: "#{user.username}'s Library"
    assert_select "p", text: "Test Book"
  end
end
