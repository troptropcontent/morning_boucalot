Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :photos
  resources :albums
  resources :album_photos, only: %i[create destroy]

  root "photos#index"
end
