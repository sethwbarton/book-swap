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
      Rails.logger.info("=" * 60)
      Rails.logger.info("STRIPE WEBHOOK: checkout.session.completed")
      Rails.logger.info("=" * 60)
      Rails.logger.info("Session ID: #{session.id}")
      Rails.logger.info("Payment Intent: #{session.payment_intent}")
      Rails.logger.info("Session object class: #{session.class.name}")
      Rails.logger.info("-" * 60)
      Rails.logger.info("Full session data:")
      Rails.logger.info(JSON.pretty_generate(session.to_hash)) if session.respond_to?(:to_hash)
      Rails.logger.info("-" * 60)
      Rails.logger.info("Collected information: #{session.collected_information.inspect}")
      Rails.logger.info("=" * 60)

      purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
      Rails.logger.info("Found purchase: #{purchase&.id || 'NOT FOUND'}")
      return unless purchase

      shipping = session.collected_information.shipping_details
      Rails.logger.info("Extracting shipping - name: #{shipping&.name}, address: #{shipping&.address.inspect}")

      purchase.update!(
        stripe_payment_intent_id: session.payment_intent,
        shipping_name: shipping.name,
        shipping_address_line1: shipping.address.line1,
        shipping_address_line2: shipping.address.line2,
        shipping_city: shipping.address.city,
        shipping_state: shipping.address.state,
        shipping_postal_code: shipping.address.postal_code,
        shipping_country: shipping.address.country
      )
      Rails.logger.info("Purchase #{purchase.id} updated with shipping address")

      purchase.complete!
      Rails.logger.info("Purchase #{purchase.id} marked as complete")
    rescue => e
      Rails.logger.error("Failed to complete purchase #{purchase&.id}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
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
