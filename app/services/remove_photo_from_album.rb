class RemovePhotoFromAlbum < ApplicationService
  def initialize(album_photo:)
    @album_photo = album_photo
  end

  def call
    @album_photo.destroy
  end
end
