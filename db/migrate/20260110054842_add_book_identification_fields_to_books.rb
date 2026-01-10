class AddBookIdentificationFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :isbn_10, :string
    add_column :books, :isbn_13, :string
    add_column :books, :description, :text
    add_column :books, :cover_image_url, :string
    add_column :books, :publisher, :string
    add_column :books, :publication_year, :integer
    add_column :books, :page_count, :integer
    add_column :books, :identified_by, :string

    add_index :books, :isbn_10
    add_index :books, :isbn_13
  end
end
