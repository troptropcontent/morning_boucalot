class AlbumsController < ApplicationController
  before_action :set_album, only: %i[show edit update destroy]

  def index
    @pagy, @albums = pagy(Current.user.albums.includes(:cover_photo).order(:title), limit: 24)
  end

  def show
    @photos = @album.photos.with_attached_file.order("album_photos.position ASC, photos.created_at DESC")
  end

  def new
    @album = Album.new
  end

  def create
    result = CreateAlbum.call(user: Current.user, params: album_params)

    if result.success?
      redirect_to result.data, notice: "Album created."
    else
      @album = Album.new
      flash.now[:alert] = result.errors.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    result = UpdateAlbum.call(album: @album, params: album_params)

    if result.success?
      redirect_to @album, notice: "Album updated."
    else
      flash.now[:alert] = result.errors.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    DeleteAlbum.call(album: @album)
    redirect_to albums_path, notice: "Album deleted."
  end

  private

  def set_album
    @album = Current.user.albums.find(params[:id])
  end

  def album_params
    params.require(:album).permit(:title, :description)
  end
end
