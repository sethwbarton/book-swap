# frozen_string_literal: true

module Books
  class ScansController < ApplicationController
    include RequiresStripeConnection

    def show
      @book = Book.new
    end
  end
end
