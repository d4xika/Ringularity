module Api
  class AliveController < ActionController::API
    def alive
      return render json: { status: "hallo cutie patutie" }
    end
  end
end
