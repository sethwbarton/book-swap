class AddShippingAddressToPurchases < ActiveRecord::Migration[8.0]
  def change
    add_column :purchases, :shipping_name, :string
    add_column :purchases, :shipping_address_line1, :string
    add_column :purchases, :shipping_address_line2, :string
    add_column :purchases, :shipping_city, :string
    add_column :purchases, :shipping_state, :string
    add_column :purchases, :shipping_postal_code, :string
    add_column :purchases, :shipping_country, :string
  end
end
