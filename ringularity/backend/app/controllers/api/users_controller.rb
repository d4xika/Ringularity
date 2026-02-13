module Api
  class UsersController < ApplicationController
    def register
      user = User.find_by(email: params[:email])

      unless user == nil
        return render json: { error: "Email already in use" }, status: :unprocessable_entity
      end

      birthday = Date.strptime(params[:birthdate], '%d.%m.%Y')

      User.create(email: params[:email], name: params[:name], birthday: birthday, password: params[:password])
      return render json: { status: "User created" }
    end

    def login
      user = User.find_by(email: params[:email], password: params[:password])
      if user == nil
        return render json: { error: "Wrong email or password" }, status: :unauthorized
      end

      return render json: { user_id: user.id }
    end
  end
end