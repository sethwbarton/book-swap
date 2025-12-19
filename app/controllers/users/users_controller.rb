module Users
  class UsersController < ApplicationController
    def show
      @user = User.find(params[:username])
    end

    def index
      @users = User.all
    end

    private

    def user_params
      params.require(:user).permit(:username)
    end
  end
end
