class AddPriceToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :price, :decimal, precision: 14, scale: 2
  end
end
