class BooksController < ApplicationController
  def index
    @books = Book.where.not(user_id: Current.user.id)
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
end
