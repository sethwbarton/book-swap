require "application_system_test_case"

class BooksTest < ApplicationSystemTestCase
  def setup
    login_as users(:one)
  end

  test "visiting the show page, creating a book, and seeing it on the show page" do
    visit root_path

    # Click button to create a new book
    click_button "Create Book"

    # Fill out the form
    fill_in "Title", with: "The Great Gatsby"
    fill_in "Author", with: "F. Scott Fitzgerald"
    click_button "Create Book"

    # Should be redirected back to the show page (root)
    assert_current_path root_path
    # Assert that the book just created exists on the page
    assert_text "The Great Gatsby"
    assert_text "F. Scott Fitzgerald"
  end
end
