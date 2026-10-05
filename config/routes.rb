Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resource :guest_session, only: %i[create edit update destroy]
  resources :passwords, param: :token

  scope "/:user_id", as: :user do
    resources :photos do
      member do
        patch :favorite
      end
      collection do
        get :upload
        patch :batch
        post :download_zip
      end
      delete "", action: :batch_destroy, on: :collection
    end

    resources :offloaded_photos, only: %i[index] do
      member do
        patch :publish
        delete :discard
      end
    end
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  root "home#index"
end
