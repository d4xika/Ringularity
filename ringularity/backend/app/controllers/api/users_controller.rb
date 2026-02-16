module Api
  class UsersController < ApplicationController
    def register
      user = User.find_by(email: params[:email])

      unless user == nil
        return render json: { error: "Email already in use" }, status: :unprocessable_entity
      end

      birthday = Date.strptime(params[:birthdate], '%d.%m.%Y')

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user = User.create(email: params[:email], name: params[:name], birthday: birthday, password: params[:password], auth_key: auth_key)
      return render json: { user_id: user.id, auth_key: auth_key }
    end

    def login
      user = User.find_by(email: params[:email])
      if !user || !user.authenticate(params[:password])
        return render json: { error: "Wrong email or password" }, status: :unauthorized
      end

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update_column(:auth_key, auth_key)

      return render json: { user_id: user.id, auth_key: auth_key }
    end

    def authorize
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])
      if user == nil
        return head(:unauthorized)
      end

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update_column(:auth_key, auth_key)

      return render json: {user_id: user.id, auth_key: auth_key}, status: :ok
    end
  end
end