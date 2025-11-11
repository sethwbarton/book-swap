module Users
  class StripeConnectionsController < ApplicationController
    Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)

    def create
      begin
        @user = User.find(params[:user_id])
        account = Stripe::Account.create

        connected_account_id = account[:id]
        @user.stripe_account_id = connected_account_id
        @user.save

        account_link = Stripe::AccountLink.create({
                                                    account: connected_account_id,
                                                    return_url: "http://localhost:3000/return/#{connected_account_id}",
                                                    refresh_url: "http://localhost:3000/refresh/#{connected_account_id}",
                                                    type: "account_onboarding"
                                                  })

        redirect_to account_link.url, allow_other_host: true
      rescue => error
        Rails.logger.error("Stripe account onboarding error: #{error.message}")
        render json: { error: error.message }, status: :internal_server_error
      end
    end

    private

    def stripe_connection_params
      params.require(:user_id)
    end
  end
end
