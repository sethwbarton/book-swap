class PurchasesController < ApplicationController
  Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)

  before_action :set_book

  def new
    # Check if book is available
    unless book_available_for_purchase?
      redirect_to book_path(@book), alert: "This book is no longer available for purchase."
      return
    end

    # Check if trying to buy own book
    if @book.user == Current.user
      redirect_to book_path(@book), alert: "You cannot purchase your own book."
      return
    end

    @seller = @book.user
  end

  def create
    # Check if book is available
    unless book_available_for_purchase?
      redirect_to book_path(@book), alert: "This book is no longer available for purchase."
      return
    end

    # Check if trying to buy own book
    if @book.user == Current.user
      redirect_to book_path(@book), alert: "You cannot purchase your own book."
      return
    end

    # Calculate fees
    book_price_cents = (@book.price * 100).to_i
    fees = Purchase.calculate_fees(book_price_cents)

    # Create pending purchase
    @purchase = Purchase.new(
      book: @book,
      buyer: Current.user,
      seller: @book.user,
      amount_cents: book_price_cents,
      platform_fee_cents: fees[:platform_fee_cents],
      seller_amount_cents: fees[:seller_amount_cents],
      status: "pending"
    )

    if @purchase.save
      begin
        # Create Stripe Checkout Session
        session = Stripe::Checkout::Session.create(
          mode: "payment",
          line_items: [ {
                         price_data: {
                           currency: "usd",
                           unit_amount: book_price_cents,
                           product_data: {
                             name: @book.title,
                             description: "by #{@book.author}"
                           }
                         },
                         quantity: 1
                       } ],
          success_url: book_url(@book),
          cancel_url: new_book_purchase_url(@book),
          metadata: {
            purchase_id: @purchase.id
          }
        )

        # Save Stripe session ID
        @purchase.update!(stripe_checkout_session_id: session.id)

        # Redirect to Stripe Checkout
        redirect_to session.url, allow_other_host: true
      rescue Stripe::StripeError => e
        # Log the error and delete purchase if Stripe fails
        Rails.logger.error("Stripe checkout session creation failed: #{e.message}")
        @purchase.destroy
        redirect_to new_book_purchase_path(@book), alert: "There was an error processing your request. Please try again."
      end
    else
      redirect_to book_path(@book), alert: @purchase.errors.full_messages.join(", ")
    end
  end

  private

  def set_book
    @book = Book.find(params[:book_id])
  end

  def book_available_for_purchase?
    @book.available? && !@book.purchases.where(status: [ "pending", "completed" ]).exists?
  end
end
