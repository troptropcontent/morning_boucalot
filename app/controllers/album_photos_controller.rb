class AlbumPhotosController < ApplicationController
  def create
    album = Current.user.albums.find(params[:album_id])
    photo = Current.user.photos.find(params[:photo_id])

    result = AddPhotoToAlbum.call(album: album, photo: photo)

    if result.success?
      redirect_to album, notice: "Photo added to album."
    else
      redirect_to album, alert: result.errors.join(", ")
    end
  end

  def destroy
    album_photo = AlbumPhoto.joins(:album).where(albums: { user_id: Current.user.id }).find(params[:id])
    album = album_photo.album
    RemovePhotoFromAlbum.call(album_photo: album_photo)
    redirect_to album, notice: "Photo removed from album."
  end
end
