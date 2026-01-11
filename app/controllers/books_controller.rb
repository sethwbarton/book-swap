class BooksController < ApplicationController
  before_action :require_stripe_connection, only: [ :new, :create, :scan, :scan_barcode, :scan_photo, :scan_manual, :scan_confirm ]

  def index
    @books = Book.available
  end

  def new
    @book = Book.new
  end

  def scan
    @book = Book.new
  end

  def scan_barcode
    @book = Book.new
    render partial: "books/scan/barcode_scanner", layout: false
  end

  def scan_photo
    @book = Book.new
    render partial: "books/scan/photo_capture", layout: false
  end

  def scan_manual
    @book = Book.new
    render partial: "books/scan/manual_form", locals: { book: @book }, layout: false
  end

  def scan_confirm
    @book = Book.new(book_params_from_lookup)
    @duplicate = Current.user.books.exists?(isbn_13: @book.isbn_13) if @book.isbn_13.present?
    render partial: "books/scan/confirm_form", locals: { book: @book, duplicate: @duplicate }, layout: false
  end

  def show
    @book = Book.find(params[:id])
  end

  def create
    @book = Book.new(book_params)
    @book.user = Current.user

    if @book.save
      redirect_to user_path(Current.user.username), notice: "Book was successfully listed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def book_params
    params.require(:book).permit(
      :title,
      :author,
      :price,
      :isbn_10,
      :isbn_13,
      :description,
      :cover_image_url,
      :publisher,
      :publication_year,
      :page_count,
      :identified_by,
      condition_photos: []
    )
  end

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

  def require_stripe_connection
    unless Current.user.stripe_account_id.present?
      redirect_to new_book_path if action_name == "create"
      @stripe_connected = false
      return
    end
    @stripe_connected = true
  end
end
