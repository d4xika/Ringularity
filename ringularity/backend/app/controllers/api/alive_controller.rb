module Api
  class AliveController < ApplicationController
    def alive
      return render json: { status: "hallo cutie patutie" }, status: :ok
    end
  end
end
