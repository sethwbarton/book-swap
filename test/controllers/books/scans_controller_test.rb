require "test_helper"

module Books
  class ScansControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:seller_one)
      login_as(@user)
    end

    test "GET /books/scans renders the scanning interface" do
      get books_scans_path
      assert_response :success

      assert_select "h1", text: "Add a Book"
      # Should show method selection options as links (inside turbo-frame)
      assert_select "a[href='#{books_scans_barcode_path}']", text: /Scan Barcode/
      assert_select "a[href='#{books_scans_photo_path}']", text: /Take Photo/
    end

    test "GET /books/scans renders a way to enter the ISBN manually" do
      get books_scans_path
      assert_response :success

      assert_select "label", text: "ISBN"
      assert_select "input[type='submit'][value='Get Details for ISBN Manually']", count: 1
    end

    test "GET /books/scans without Stripe account shows payment setup prompt" do
      @user.update!(stripe_account_id: nil)

      get books_scans_path
      assert_response :success

      assert_select "p", text: /Before you can list books for sale/i
    end

    private

    def login_as(user)
      post session_path, params: { email_address: user.email_address, password: "password" }
      follow_redirect! if response.redirect?
    end
  end
end
