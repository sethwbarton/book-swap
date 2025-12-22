class UnauthController < ApplicationController
  allow_unauthenticated_access

  def index
    render "unauth/index"
  end
end
