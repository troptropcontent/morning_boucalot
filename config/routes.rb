Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resources :passwords, param: :token

  resources :photos do
    collection do
      get :upload
    end
  end
root "photos#index"
end
