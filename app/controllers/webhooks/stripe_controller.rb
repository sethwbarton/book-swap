module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    allow_unauthenticated_access

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, webhook_secret
        )
      rescue JSON::ParserError => e
        render json: { error: "Invalid payload" }, status: :bad_request
        return
      rescue Stripe::SignatureVerificationError => e
        render json: { error: "Invalid signature" }, status: :bad_request
        return
      end

      # Handle the event
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "checkout.session.expired"
        handle_checkout_expired(event.data.object)
      when "payment_intent.payment_failed"
        handle_payment_failed(event.data.object)
      end

      render json: { message: "success" }, status: :ok
    end

    private

    def handle_checkout_completed(session)
      purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
      return unless purchase

      purchase.update!(
        stripe_payment_intent_id: session.payment_intent,
        status: "completed"
      )
      purchase.complete!
    rescue => e
      Rails.logger.error("Failed to complete purchase #{purchase&.id}: #{e.message}")
    end

    def handle_checkout_expired(session)
      purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
      return unless purchase

      purchase.cancel!
    rescue => e
      Rails.logger.error("Failed to cancel purchase #{purchase&.id}: #{e.message}")
    end

    def handle_payment_failed(payment_intent)
      purchase = Purchase.find_by(stripe_payment_intent_id: payment_intent.id)
      return unless purchase

      purchase.cancel!
    rescue => e
      Rails.logger.error("Failed to cancel purchase #{purchase&.id}: #{e.message}")
    end
  end
end
