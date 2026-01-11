# frozen_string_literal: true

module RequiresStripeConnection
  extend ActiveSupport::Concern

  included do
    before_action :check_stripe_connection
  end

  private

  def check_stripe_connection
    @stripe_connected = Current.user.stripe_account_id.present?
  end
end
