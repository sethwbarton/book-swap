class AddStripeFieldsToPurchases < ActiveRecord::Migration[8.0]
  def change
    add_column :purchases, :status, :string, default: "pending", null: false
    add_column :purchases, :stripe_checkout_session_id, :string
    add_column :purchases, :stripe_payment_intent_id, :string
    add_column :purchases, :stripe_transfer_id, :string
    add_column :purchases, :amount_cents, :integer, null: false
    add_column :purchases, :platform_fee_cents, :integer, null: false
    add_column :purchases, :seller_amount_cents, :integer, null: false
    add_column :purchases, :cancelled_at, :datetime

    add_index :purchases, :status
    add_index :purchases, :stripe_checkout_session_id
    add_index :purchases, :stripe_payment_intent_id
  end
end
