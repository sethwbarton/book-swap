require "test_helper"
require "mocha/minitest"
require "ostruct"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @buyer = users(:buyer_one)
    @seller = users(:seller_one)
    @book = books(:the_great_gatsby)

    @purchase = Purchase.create!(
      book: @book,
      buyer: @buyer,
      seller: @seller,
      amount_cents: 1299,
      platform_fee_cents: 130,
      seller_amount_cents: 1169,
      status: "pending",
      stripe_checkout_session_id: "cs_test_123"
    )

    @webhook_secret = "whsec_test_secret"
    Rails.application.credentials.stubs(:dig).with(:stripe, :webhook_secret).returns(@webhook_secret)
  end

  test "handles checkout.session.completed event" do
    event_data = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => "cs_test_123",
          "payment_intent" => "pi_test_123",
          "metadata" => {
            "purchase_id" => @purchase.id.to_s
          }
        }
      }
    }

    # Create an OpenStruct that mimics Stripe::Event
    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(
        object: OpenStruct.new(
          id: "cs_test_123",
          payment_intent: "pi_test_123",
          metadata: {
            purchase_id: @purchase.id.to_s
          }
        )
      )
    )

    # Mock Stripe signature verification
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "test_signature" }

    assert_response :success

    @purchase.reload
    assert_equal "completed", @purchase.status
    assert_equal "pi_test_123", @purchase.stripe_payment_intent_id
    assert @book.reload.sold
  end

  test "handles checkout.session.expired event" do
    event_data = {
      "type" => "checkout.session.expired",
      "data" => {
        "object" => {
          "id" => "cs_test_123",
          "metadata" => {
            "purchase_id" => @purchase.id.to_s
          }
        }
      }
    }

    event = OpenStruct.new(
      type: "checkout.session.expired",
      data: OpenStruct.new(
        object: OpenStruct.new(
          id: "cs_test_123",
          metadata: {
            purchase_id: @purchase.id.to_s
          }
        )
      )
    )

    # Mock Stripe signature verification
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "test_signature" }

    assert_response :success

    @purchase.reload
    assert_equal "cancelled", @purchase.status
    assert_not_nil @purchase.cancelled_at
    assert_not @book.reload.sold
  end

  test "handles payment_intent.payment_failed event" do
    # First need to add payment_intent to purchase
    @purchase.update!(stripe_payment_intent_id: "pi_test_123")

    event_data = {
      "type" => "payment_intent.payment_failed",
      "data" => {
        "object" => {
          "id" => "pi_test_123"
        }
      }
    }

    event = OpenStruct.new(
      type: "payment_intent.payment_failed",
      data: OpenStruct.new(
        object: OpenStruct.new(id: "pi_test_123")
      )
    )

    # Mock Stripe signature verification
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "test_signature" }

    assert_response :success

    @purchase.reload
    assert_equal "cancelled", @purchase.status
    assert_not_nil @purchase.cancelled_at
    assert_not @book.reload.sold
  end

  test "returns 400 for invalid signature" do
    event_data = { "type" => "checkout.session.completed" }

    # Mock signature verification to raise error
    Stripe::Webhook.stubs(:construct_event).raises(Stripe::SignatureVerificationError.new("Invalid signature", "sig_header"))

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "invalid_signature" }

    assert_response :bad_request
  end

  test "returns 200 for unknown event types" do
    event_data = {
      "type" => "unknown.event.type",
      "data" => { "object" => {} }
    }

    event = OpenStruct.new(
      type: "unknown.event.type",
      data: OpenStruct.new(object: {})
    )

    # Mock Stripe signature verification
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "test_signature" }

    assert_response :success
  end

  test "handles missing purchase gracefully" do
    event_data = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => "cs_test_nonexistent",
          "payment_intent" => "pi_test_123",
          "metadata" => {
            "purchase_id" => "99999"
          }
        }
      }
    }

    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(
        object: OpenStruct.new(
          id: "cs_test_nonexistent",
          payment_intent: "pi_test_123",
          metadata: {
            purchase_id: "99999"
          }
        )
      )
    )

    # Mock Stripe signature verification
    Stripe::Webhook.stubs(:construct_event).returns(event)

    post webhooks_stripe_path, params: event_data.to_json, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "test_signature" }

    assert_response :success
  end
end
