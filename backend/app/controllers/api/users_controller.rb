module Api
  # Handles user lifecycle including authentication, profile updates, and data export.
  class UsersController < ApplicationController

    # Registers a new user and returns an initial auth key.
    # @param email [String] Unique email address
    # @param name [String] Display name
    # @param birthdate [String] Birthday in format 'DD.MM.YYYY'
    # @param password [String] Plain text password
    # @return [JSON] User profile and auth_key
    def register
      user = User.find_by(email: params[:email])

      unless user == nil
        return render json: { error: "Email already in use" }, status: :unprocessable_entity
      end

      # Parsing the custom date format from Flutter
      birthday = Date.strptime(params[:birthdate], '%d.%m.%Y')
      auth_key = "ringularity-#{SecureRandom.hex(16)}"

      user = User.create(email: params[:email], name: params[:name], birthday: birthday, password: params[:password], auth_key: auth_key)
      render_user_with_auth(user, auth_key)
    end

    # Authenticates a user and generates a new session key.
    # @param email [String]
    # @param password [String]
    # @return [JSON] User profile and new auth_key
    def login
      user = User.find_by(email: params[:email])
      if !user || !user.authenticate(params[:password])
        return render json: { error: "Wrong email or password" }, status: :unauthorized
      end

      auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update(auth_key: auth_key)

      render_user_with_auth(user, auth_key)
    end

    # Updates basic profile information.
    # @param user_id [Integer]
    # @param auth_key [String]
    # @param name [String] New name
    # @param birthday [Date] New birthday
    def update
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])
      return head(:unauthorized) if user.nil?

      if user.update(name: params[:name], birthday: params[:birthday])
        new_auth_key = "ringularity-#{SecureRandom.hex(16)}"
        user.update(auth_key: new_auth_key)

        render json: {
          user_id: user.id,
          auth_key: new_auth_key,
          user_info: { name: user.name, email: user.email, birthday: user.birthday }
        }, status: :ok
      else
        render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    # Updates sensitive user credentials (email or password).
    # Requires current password verification for safety.
    #
    # @param user_id [Integer]
    # @param auth_key [String]
    # @param current_password [String] Required to authorize the change
    # @param new_email [String, nil] Optional new email address
    # @param new_password [String, nil] Optional new password
    # @return [JSON] Updated user info and a fresh auth_key
    def security_update
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])

      if user == nil
        return head(:unauthorized)
      end

      # Verify identity before allowing sensitive changes
      unless user.authenticate(params[:current_password])
        return render json: { error: "Current password incorrect" }, status: :unauthorized
      end

      if params[:new_email].present?
        user.email = params[:new_email]
      elsif params[:new_password].present?
        user.password = params[:new_password]
      end

      if user.save
        # Generate a fresh key after security changes (Best Practice)
        new_key = "ringularity-#{SecureRandom.hex(16)}"
        user.update(auth_key: new_key)

        render json: {
          auth_key: new_key,
          user_id: user.id, 
          user_info: { email: user.email, name: user.name, birthday: user.birthday }
        }, status: :ok
      else
        render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    # Exports all health data and activities for a user as a single JSON.
    # @note Can be authorized via Headers (X-User-Id, X-Auth-Key) or Params.
    # @return [JSON] Full data dump for the user
    def export_data
      user_id = request.headers['X-User-Id'] || params[:user_id]
      auth_key = request.headers['X-Auth-Key'] || params[:auth_key]

      user = User.find_by(id: user_id, auth_key: auth_key)
      return head(:unauthorized) if user.nil?

      export_payload = {
        metadata: { user_id: user.id, export_date: Time.current, app_version: "1.1.0" },
        user_profile: { name: user.name, email: user.email, birthday: user.birthday },
        health_data: {
          heart_rate: user.heart_rate_logs.order(recorded_at: :desc),
          stress: user.stress_logs.order(recorded_at: :desc),
          hrv: user.hrv_logs.order(recorded_at: :desc),
          sleep: user.sleep_logs.order(recorded_at: :desc),
          steps: user.steps_logs.order(recorded_at: :desc)
        },
        activities: user.activity_logs.order(recorded_at: :desc)
      }

      render json: export_payload, status: :ok
    end

    # Refreshes the session key for an already logged-in user.
    # Used by the Flutter app on startup to verify if the stored credentials are still valid.
    #
    # @param user_id [Integer] The ID of the user trying to re-authorize.
    # @param auth_key [String] The current (old) auth_key stored on the device.
    # @return [JSON] Updated user info and a fresh auth_key if successful.
    # @return [Status 401] If the user_id and auth_key combo is invalid.
    def authorize
      user = User.find_by(id: params[:user_id], auth_key: params[:auth_key])
      if user == nil
        return head(:unauthorized)
      end

      # Generate a new key to rotate the session (security best practice)
      new_auth_key = "ringularity-#{SecureRandom.hex(16)}"
      user.update(auth_key: new_auth_key) # FIX: new_auth_key statt der alten Variable nutzen

      return render_user_with_auth(user, new_auth_key)
    end

    private

    # Helper to standardize the user response format.
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