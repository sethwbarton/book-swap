class UnauthController < ApplicationController
  allow_unauthenticated_access

  def index
    if authenticated?
      @books = Current.user.books
      render "books/index"
    else
      render "unauth/index"
    end
  end
end
