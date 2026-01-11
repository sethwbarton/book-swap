# frozen_string_literal: true

module Books
  module Entries
    class ConfirmationsController < ApplicationController
      include RequiresStripeConnection

      def show
        @book = Book.new(book_params_from_lookup)
        @duplicate = Current.user.books.exists?(isbn_13: @book.isbn_13) if @book.isbn_13.present?
      end

      private

      def book_params_from_lookup
        params.permit(
          :title,
          :author,
          :isbn_10,
          :isbn_13,
          :description,
          :cover_image_url,
          :publisher,
          :publication_year,
          :page_count,
          :identified_by
        )
      end
    end
  end
end
