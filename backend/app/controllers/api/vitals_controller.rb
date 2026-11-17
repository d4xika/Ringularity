module Api
  # Manages all health-related data streams from the ring.
  # Uses bulk upserts for repeatable synchronization and provides range-based retrieval.
  class VitalsController < ApplicationController
    before_action :authenticate_user

    # @!group Synchronization Endpoints (Bulk Upsert)

    # Inserts or updates heart rate logs.
    # @param _json [Array<Hash>] List of entries: { bpm: Integer, recorded_at: DateTime }
    def heart_rate_logs
      process_bulk_upsert(HeartRateLog, [:bpm, :recorded_at])
    end

    # Inserts or updates stress level logs.
    # @param _json [Array<Hash>] List of entries: { stress_level: Integer, recorded_at: DateTime }
    def stress_logs
      process_bulk_upsert(StressLog, [:stress_level, :recorded_at])
    end

    # Inserts or updates HRV (Heart Rate Variability) logs.
    # @param _json [Array<Hash>] List of entries: { hrv_val: Integer, recorded_at: DateTime }
    def hrv_logs
      process_bulk_upsert(HrvLog, [:hrv_val, :recorded_at])
    end

    # Inserts or updates steps count logs.
    # @param _json [Array<Hash>] List of entries: { steps: Integer, recorded_at: DateTime }
    def steps_logs
      process_bulk_upsert(StepsLog, [:steps, :recorded_at])
    end

    # Inserts or updates sleep stage data.
    # @param _json [Array<Hash>] List of entries: { sleep_stage: String, duration_minutes: Integer, recorded_at: DateTime }
    def sleep_logs
      process_bulk_upsert(SleepLog, [:sleep_stage, :duration_minutes, :recorded_at])
    end

    # @!group Retrieval Endpoints (Time Range)

    # Gets heart rate logs for a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of HeartRateLog objects
    def get_heart_rate_logs
      render_range(@user.heart_rate_logs)
    end

    # Gets stress logs for a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of StressLog objects
    def get_stress_logs
      render_range(@user.stress_logs)
    end

    # Gets HRV logs for a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of HrvLog objects
    def get_hrv_logs
      render_range(@user.hrv_logs)
    end

    # Gets sleep logs for a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of SleepLog objects
    def get_sleep_logs
      data = @user.sleep_logs.where(
        "recorded_at < :finish AND recorded_at + duration_minutes * INTERVAL '1 minute' > :start",
        start: params[:recorded_at_start], finish: params[:recorded_at_end]
      )
      render json: data.order(:recorded_at), status: :ok
    end

    # Gets steps logs for a time range.
    # @param recorded_at_start [DateTime] Range start
    # @param recorded_at_end [DateTime] Range end
    # @return [JSON] Array of StepsLog objects
    def get_steps_logs
      render_range(@user.steps_logs)
    end

    private

    # Inserts new timestamps and updates existing measurements within the authenticated user.
    def process_bulk_upsert(model_class, attributes)
      insert_data = params[:_json].map do |entry|
        data = { user_id: @user.id }
        attributes.each { |attr| data[attr] = entry[attr] }
        data
      end

      insert_data = insert_data.index_by { |entry| entry[:recorded_at] }.values
      model_class.upsert_all(insert_data, unique_by: [:recorded_at, :user_id], update_only: attributes - [:recorded_at])
      head :ok
    end

    # Renders a half-open time range so adjacent calendar days do not overlap.
    def render_range(relation)
      data = relation.where(recorded_at: params[:recorded_at_start]...params[:recorded_at_end])
      render json: data, status: :ok
    end

    # Validates credentials via Headers and session age.
    # @note Session expires after 3 days of user inactivity.
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