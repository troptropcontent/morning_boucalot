Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resources :passwords, param: :token

  scope "/:user_id", as: :user do
    resources :photos do
      collection do
        get :upload
        patch :batch
      end
    end
  end

  root "home#index"
end
