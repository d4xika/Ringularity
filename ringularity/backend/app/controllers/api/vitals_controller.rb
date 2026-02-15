module Api
  class VitalsController < ApplicationController
    def heart_rate_logs
      pp params
      # {"recorded_at" => "2026-02-15T16:45:00.000", "bpm" => 76, "device_id" => "37CA53C4-9D79-1688-B05B-BFF64F1CB7C4"}
    end
  end
end