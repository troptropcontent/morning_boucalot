Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resource :guest_session, only: %i[create edit update destroy]
  resources :passwords, param: :token

  post "offload_uploads", to: "offload_uploads#create"
  post "raf_uploads/presign", to: "raf_uploads#presign"
  post "offload_uploads/check", to: "offload_upload_checks#create", as: :offload_upload_checks

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

    resources :offloaded_photos, only: %i[index show] do
      member do
        patch :publish
        delete :discard
      end
    end

    resources :archived_photos, path: "trash", only: %i[index destroy] do
      member do
        patch :restore
      end
      collection do
        patch :batch_restore
      end
      delete "", action: :batch_destroy, on: :collection
    end
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  root "home#index"
end
