Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "books#index"

  resources :purchases, only: [ :new ]
  resources :books, only: [ :show, :new, :create ]
  resources :users, only: [ :index ] do
    scope module: :users do
      resource :stripe_connection, only: [ :create ]
      get "/stripe_connection/return/:stripe_account_id", to: "stripe_connections#return"
      get "/stripe_connection/refresh_link/:stripe_account_id", to: "stripe_connections#refresh_link"
    end
  end
  get "/users/:username" => "users#show", as: :user
end
