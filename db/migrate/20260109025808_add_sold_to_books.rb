class AddSoldToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :sold, :boolean, default: false, null: false
    add_index :books, :sold
  end
end
