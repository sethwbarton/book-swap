# frozen_string_literal: true

module Books
  module Scans
    class BarcodesController < ApplicationController
      include RequiresStripeConnection

      def show
        @book = Book.new
      end
    end
  end
end
