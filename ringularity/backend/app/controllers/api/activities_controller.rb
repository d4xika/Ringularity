module Api
  class ActivitiesController < ApplicationController
    before_action :authenticate_user
    def activity_logs
      insert_data = params[:_json].map do |entry|
        {
          activity_type: entry[:type],
          custom_title: entry[:customTitle],
          recorded_at: entry[:date],
          duration: entry[:durationSeconds],
          distance: entry[:distanceKm],
          avg_heart_rate: entry[:avgHeartRate],
          steps: entry[:steps],
          hr_trace: entry[:hrTrace],
          route: entry[:route],
          user_id: @user.id
        }
      end

      ActivityLog.insert_all(insert_data, unique_by: [:recorded_at, :user_id])
    end

    def get_activity_logs
      activity_logs = @user.activity_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: activity_logs, status: :ok
    end

    def delete_activity_logs
      begin
        t = Time.zone.parse(params[:recorded_at])
      rescue
        return render json: { error: "Invalid date" }, status: :bad_request
      end

      deleted_count = @user.activity_logs.where(
        recorded_at: (t - 0.5.seconds)..(t + 0.5.seconds)
      ).delete_all

      if deleted_count > 0
        render status: :ok
      else
        render json: { error: "Not found", sent_timestamp: params[:recorded_at] }, status: :not_found
      end
    end

    private

    def authenticate_user
      user_id = request.headers["X-User-Id"]
      auth_key = request.headers["X-Auth-Key"]
      @user = User.find_by(id: user_id, auth_key: auth_key)

      if !@user || @user.updated_at < 3.days.ago
        render json: { error: 'Not Authorized' }, status: :unauthorized
      end
    end
  end
end