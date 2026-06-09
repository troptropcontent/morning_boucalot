class AddPhotoToAlbum < ApplicationService
  def initialize(album:, photo:)
    @album = album
    @photo = photo
  end

  def call
    album_photo = @album.album_photos.build(photo: @photo)
    fail!(album_photo.errors.full_messages) unless album_photo.save
    album_photo
  end
end
