require "application_system_test_case"

class BooksTest < ApplicationSystemTestCase
  test "visiting the new book page shows the new book form" do
    visit new_book_path
    
    assert_selector "h1", text: "Add a New Book"
    assert_field "Title"
    assert_field "Author"
    assert_button "Create Book"
  end

  test "creating a new book" do
    visit new_book_path
    
    fill_in "Title", with: "The Great Gatsby"
    fill_in "Author", with: "F. Scott Fitzgerald"
    click_button "Create Book"
    
    assert_text "Book was successfully created"
    # After redirect, we're back at the new form
    assert_selector "h1", text: "Add a New Book"
  end

  test "error messages are displayed when creating a book with invalid data" do
    visit new_book_path
    
    # Try to submit form without filling in any fields
    click_button "Create Book"
    
    # Verify error message container appears with correct styling
    assert_selector ".bg-red-100.border-red-400.text-red-700"
    # Verify error header text (pluralized)
    assert_text "errors prohibited this book from being saved"
    # Verify specific error messages for title and author
    assert_text "Title can't be blank"
    assert_text "Author can't be blank"
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

