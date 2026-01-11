require "test_helper"

module Books
  module Scans
    class BarcodesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:seller_one)
        login_as(@user)
      end

      test "GET /books/scans/barcode directly renders full page with layout" do
        get books_scans_barcode_path
        assert_response :success

        # Should have full HTML document with head (CSS/JS loaded)
        assert_select "html"
        assert_select "head link[rel='stylesheet']"
        assert_select "body"

        # Should have the page title
        assert_select "h1", text: "Add a Book"

        # Should have the turbo frame with barcode scanner content
        assert_select "turbo-frame#scan_step"
        assert_select "[data-controller='barcode-scanner']"
      end

      test "GET /books/scans/barcode without Stripe account shows payment setup prompt" do
        @user.update!(stripe_account_id: nil)

        get books_scans_barcode_path
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
end
