module Api
  class VitalsController < ApplicationController
    before_action :authenticate_user

    def heart_rate_logs
      insert_data = params[:_json].map do |entry|
        {
          bpm: entry[:bpm],
          recorded_at: entry[:recorded_at],
          user_id: @user.id
        }
      end

      HeartRateLog.insert_all(insert_data, unique_by: [:recorded_at, :user_id])
    end

    def stress_logs
      data = params[:_json]
      data.each do |entry|
        StressLog.upsert(
          {
            stress_level: entry[:stress_level],
            recorded_at: entry[:recorded_at],
            user_id: @user.id
          },
          unique_by: [:recorded_at, :user_id]
        )
      end
    end

    def hrv_logs
      insert_data = params[:_json].map do |entry|
        {
          hrv_val: entry[:hrv_val],
          recorded_at: entry[:recorded_at],
          user_id: @user.id
        }
      end

      HrvLog.insert_all(insert_data, unique_by: [:recorded_at, :user_id])
    end

    def steps_logs
      insert_data = params[:_json].map do |entry|
        {
          steps: entry[:steps],
          recorded_at: entry[:recorded_at],
          user_id: @user.id
        }
      end

      StepsLog.insert_all(insert_data, unique_by: [:recorded_at, :user_id])
    end

    def sleep_logs
      insert_data = params[:_json].map do |entry|
        {
          sleep_stage: entry[:sleep_stage],
          duration_minutes: entry[:duration_minutes],
          recorded_at: entry[:recorded_at],
          user_id: @user.id
        }
      end

      SleepLog.insert_all(insert_data, unique_by: [:recorded_at, :user_id])
    end

    def get_heart_rate_logs
      heart_rate_logs = @user.heart_rate_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: heart_rate_logs, status: :ok
    end

    def get_stress_logs
      stress_logs = @user.stress_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: stress_logs, status: :ok
    end

    def get_hrv_logs
      hrv_logs = @user.hrv_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: hrv_logs, status: :ok
    end

    def get_sleep_logs
      sleep_logs = @user.sleep_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: sleep_logs, status: :ok
    end

    def get_steps_logs
      steps_logs = @user.steps_logs.where(recorded_at: params[:recorded_at_start]..params[:recorded_at_end])
      return render json: steps_logs, status: :ok
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