require "application_system_test_case"

class BooksTest < ApplicationSystemTestCase
  test "visiting the root page shows the new book form" do
    visit root_path
    
    assert_selector "h1", text: "Add a New Book"
    assert_field "Title"
    assert_field "Author"
    assert_button "Create Book"
  end

  test "creating a new book" do
    visit root_path
    
    fill_in "Title", with: "The Great Gatsby"
    fill_in "Author", with: "F. Scott Fitzgerald"
    click_button "Create Book"
    
    assert_text "Book was successfully created"
    # After redirect, we're back at the new form
    assert_selector "h1", text: "Add a New Book"
  end
end

