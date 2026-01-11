# frozen_string_literal: true

module Books
  module Scans
    class PhotosController < ApplicationController
      include RequiresStripeConnection

      def show
        @book = Book.new
      end
    end
  end
end
