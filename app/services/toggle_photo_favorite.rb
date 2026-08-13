class TogglePhotoFavorite < ApplicationService
  def initialize(photo:, user:)
    @photo = photo
    @user = user
  end

  def call
    favorite = @photo.favorites.find_by(user: @user)

    if favorite
      favorite.destroy!
      false
    else
      @photo.favorites.create!(user: @user)
      true
    end
  end
end
