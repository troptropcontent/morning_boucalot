class TogglePhotoFavorite < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    @photo.update!(favorited: !@photo.favorited)
    @photo
  end
end
