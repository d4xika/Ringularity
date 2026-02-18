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
        post :stress_logs
        post :hrv_logs
        post :sleep_logs
        post :steps_logs
        get :get_heart_rate_logs
        get :get_stress_logs
        get :get_hrv_logs
        get :get_sleep_logs
        get :get_steps_logs
      end
    end

    resources :activities, only: [] do
      collection do
        post :activity_logs
        get :get_activity_logs
      end
    end
  end
end
