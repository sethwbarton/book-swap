class BooksController < ApplicationController
  include RequiresStripeConnection

  skip_before_action :check_stripe_connection, only: [ :index, :show ]

  def index
    @books = Book.available
  end

  def new
    @book = Book.new
  end

  def show
    @book = Book.find(params[:id])
  end

  def create
    unless @stripe_connected
      redirect_to new_book_path
      return
    end

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
end
