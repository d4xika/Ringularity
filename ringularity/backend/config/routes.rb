Rails.application.routes.draw do
  namespace :api do
    get "up" => "rails/health#show", as: :rails_health_check

    get "/alive", to: "alive#alive"

    resources :users, only: [] do
      collection do
        post :login
        post :register
        post :authorize
      end
    end

    resources :vitals, only: [] do
      collection do
        post :heart_rate_logs
      end
    end
  end
end
