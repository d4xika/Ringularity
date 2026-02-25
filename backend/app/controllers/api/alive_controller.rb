# API Module for health and monitoring
module Api
  # AliveController verifies the connection between Flutter and Rails.
  class AliveController < ApplicationController

    # @return [JSON] A friendly status message.
    # @example Expected Response:
    #   { "status": "hallo cutie patutie" }
    def alive
      render json: { status: "hallo cutie patutie" }, status: :ok
    end
  end
end