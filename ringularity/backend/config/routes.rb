Rails.application.routes.draw do
  namespace :api do
    get "up" => "rails/health#show", as: :rails_health_check

    get "/alive", to: "alive#alive"

    resources :users, only: [] do
      collection do
        post :login
        post :register
      end
    end
  end
end
