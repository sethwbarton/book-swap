module Users
  class StripeConnectionsController < ApplicationController
    Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)

    def create
      account = Stripe::Account.create
      stripe_account_id = account[:id]
      stripe_setup_link = get_stripe_setup_link(stripe_account_id)
      redirect_to stripe_setup_link.url, allow_other_host: true
    end

    def return
      @user = User.find(params[:user_id])
      @user.stripe_account_id = params[:stripe_account_id]
      @user.save
      render "users/stripe_connections/return"
    end

    def refresh_link
      stripe_account_id = params[:stripe_account_id]
      stripe_setup_link = get_stripe_setup_link(stripe_account_id)
      redirect_to stripe_setup_link.url, allow_other_host: true
    end

    private

    def get_stripe_setup_link(stripe_account_id)
      @user = User.find(params[:user_id])
      Stripe::AccountLink.create({
                                   account: stripe_account_id,
                                   return_url: "http://localhost:3000/users/#{@user.id}/stripe_connection/return/#{stripe_account_id}",
                                   refresh_url: "http://localhost:3000/users/#{@user.id}/stripe_connection/refresh/#{stripe_account_id}",
                                   type: "account_onboarding"
                                 })
    end

    def stripe_connection_params
      params.require(:user_id).permit(:stripe_account_id)
    end
  end
end
