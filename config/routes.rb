Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :photos do
    collection do
      get :upload
    end
  end
root "photos#index"
end
