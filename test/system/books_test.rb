require "application_system_test_case"

class BooksTest < ApplicationSystemTestCase
  def setup
    login_as users(:seller_one)
  end

  test "visiting the root page, creating a book, and seeing it on the user's page" do
    visit root_path

    # Click button to create a new book
    click_button "List A Book"

    # Should see method selection page
    assert_text "How would you like to add your book?"

    # Click to enter details manually
    click_link "Enter book details manually"

    # Should see the manual entry form
    assert_text "Enter Book Details"

    # Fill out the form
    fill_in "Title", with: "The Great Gatsby"
    fill_in "Author", with: "F. Scott Fitzgerald"
    fill_in "Your Price", with: "14.99"
    click_button "List Book for Sale"

    # Should be redirected to the User's show page so they can see their listings
    assert_current_path user_path("seller_one")
    assert_text "seller_one's Library"

    # Assert that the book just created exists on the page
    assert_text "The Great Gatsby"
    assert_text "F. Scott Fitzgerald"
    assert_text "14.99"
  end
end
