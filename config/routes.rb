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
  root "unauth#index"

  scope module: :users do
    resources :users, only: [ :index ] do
      resource :stripe_connection, only: [ :create ]
      get "/stripe_connection/return/:stripe_account_id", to: "stripe_connections#return"
      get "/stripe_connection/refresh_link/:stripe_account_id", to: "stripe_connections#refresh_link"
    end
    get "/users/:username" => "users#show", as: :user
  end

  resources :books, only: [ :show, :new, :create, :index ] do
    resources :purchases, only: [ :new, :create ]
    collection do
      get :scan
    end
  end

  # Book lookup endpoints for scanning feature
  post "/book_lookups/isbn", to: "book_lookups#isbn", as: :book_lookups_isbn
  post "/book_lookups/image", to: "book_lookups#image", as: :book_lookups_image

  # Webhook endpoint for Stripe (skip authentication)
  post "/webhooks/stripe", to: "webhooks/stripe#create"
end
