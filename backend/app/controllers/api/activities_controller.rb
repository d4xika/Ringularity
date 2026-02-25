module Api
  # Manages physical activity logs, including high-detail data like HR traces and routes.
  class ActivitiesController < ApplicationController
    before_action :authenticate_user

    # Bulk inserts activity logs from the mobile app.
    # Maps Flutter-style keys (camelCase) to database columns (snake_case).
    #
    # @param _json [Array<Hash>] List of activities:
    #   * type [String] Type of activity (e.g., 'Running')
    #   * customTitle [String] User-defined title
    #   * date [DateTime] Timestamp of the activity
    #   * durationSeconds [Integer] Duration in seconds
    #   * distanceKm [Float] Distance in kilometers
    #   * avgHeartRate [Integer] Average BPM
    #   * steps [Integer] Steps during activity
    #   * hrTrace [Array] Raw heart rate data points
    #   * route [JSON/Array] GPS route coordinates
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
      head :ok
    end

    # Retrieves activities for a specific user within a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of ActivityLog records.
    def get_activity_logs
      activity_logs = @user.activity_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      render json: activity_logs, status: :ok
    end

    # Deletes a specific activity log.
    # Uses a small time buffer (+/- 1s) to ensure the correct log is found
    # even with minor floating point precision differences.
    #
    # @param recorded_at [String] The exact timestamp of the activity to delete.
    # @return [Status 200] If deletion was successful.
    # @return [Status 404] If no matching activity was found.
    # @return [Status 400] If the date format is invalid.
    def delete_activity_logs
      begin
        t = Time.zone.parse(params[:recorded_at])
      rescue
        return render json: { error: "Invalid date" }, status: :bad_request
      end

      # Buffer range to catch the correct record
      deleted_count = @user.activity_logs.where(
        recorded_at: (t - 1.seconds)..(t + 1.seconds)
      ).delete_all

      if deleted_count > 0
        render status: :ok
      else
        render json: { error: "Not found", sent_timestamp: params[:recorded_at] }, status: :not_found
      end
    end

    private

    # Authenticates user via X-User-Id and X-Auth-Key headers.
    # @note Session is considered expired if User object has not been updated for 3 days.
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