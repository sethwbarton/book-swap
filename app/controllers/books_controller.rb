class BooksController < ApplicationController
  before_action :require_stripe_connection, only: [ :new, :create ]

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
    @book = Book.new(book_params)
    @book.user = Current.user

    if @book.save
      redirect_to user_path(Current.user.username), notice: "Book was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def book_params
    params.require(:book).permit(:title, :author, :price)
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
