# frozen_string_literal: true

class BookLookupsController < ApplicationController
  # POST /book_lookups/isbn
  # Params: { isbn: "9780061120084" }
  # Returns: JSON book data or { error: "not_found" }
  def isbn
    isbn_param = params[:isbn]

    if isbn_param.blank?
      return render json: { error: "invalid_request", message: "ISBN is required" },
                    status: :unprocessable_entity
    end

    book_data = IsbnLookupService.lookup(isbn_param)

    if book_data
      render json: with_duplicate_info(book_data)
    else
      render json: { error: "not_found", message: "No book found for this ISBN" },
             status: :not_found
    end
  end

  # POST /book_lookups/image
  # Params: { image: <uploaded file> }
  # Returns: JSON array of possible matches
  def image
    image_file = params[:image]

    if image_file.blank?
      return render json: { error: "invalid_request", message: "Image is required" },
                    status: :unprocessable_entity
    end

    matches = BookImageRecognitionService.identify(image_file.tempfile)

    if matches.any?
      matches_with_duplicates = matches.map { |match| with_duplicate_info(match) }
      render json: { matches: matches_with_duplicates }
    else
      render json: { matches: [], message: "No books identified from image" }
    end
  end

  private

  def with_duplicate_info(book_data)
    existing_book = Book.find_duplicate_for_user(
      Current.user,
      isbn_10: book_data[:isbn_10],
      isbn_13: book_data[:isbn_13]
    )

    result = book_data.dup
    result[:duplicate] = existing_book.present?

    if existing_book
      result[:existing_book_id] = existing_book.id
      result[:duplicate_message] = "You already have this book listed"
    end

    result
  end
end
