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
      return render_user_with_auth(user, auth_key)
    end

    def login
      user = User.find_by(email: params[:email])
      if !user || !user.authenticate(params[:password])
        return render json: { error: "Wrong email or password" }, status: :unauthorized
      end

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update(auth_key: auth_key)

      return render_user_with_auth(user, auth_key)
    end

    def update
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])

      if user == nil
        return head(:unauthorized)
      end

      if user.update(name: params[:name], birthday: params[:birthday])
        new_auth_key = "ringularity-#{SecureRandom.hex(16)}"
        user.update(auth_key: auth_key)

        return render json: {
          user_id: user.id,
          auth_key: new_auth_key,
          user_info: { name: user.name, email: user.email, birthday: user.birthday }
        }, status: :ok
      else
        return render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def security_update
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])

      if user == nil
        return head(:unauthorized)
      end

      unless user.authenticate(params[:current_password])
        return render json: { error: "Current password incorrect" }, status: :unauthorized
      end

      if params[:new_email].present?
        user.email = params[:new_email]
      elsif params[:new_password].present?
        user.password = params[:new_password]
      end

      if user.save
        new_key = "ringularity-#{SecureRandom.hex(16)}"
        user.update(auth_key: auth_key)

        render json: {
          auth_key: new_key,
          user_id: user.id, 
          user_info: { email: user.email, name: user.name, birthday: user.birthday }
        }, status: :ok
      else
        render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def authorize
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])
      if user == nil
        return head(:unauthorized)
      end

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update(auth_key: auth_key)

      return render_user_with_auth(user, auth_key)
    end

    private

    def render_user_with_auth(user, auth_key)
      render json: {
        user_id: user.id,
        auth_key: auth_key,
        user_info: {
          name: user.name,
          email: user.email,
          birthday: user.birthday
        }
      }, status: :ok
    end
  end
end