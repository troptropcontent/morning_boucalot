class PhotosController < ApplicationController
  before_action :set_photo, only: %i[show edit update destroy]

  def index
    @photos = Current.user.photos.with_attached_file.recent
  end

  def show
  end

  def new
    @photo = Photo.new
  end

  def create
    result = UploadPhoto.call(user: Current.user, params: photo_params)

    if result.success?
      redirect_to result.data, notice: "Photo uploaded."
    else
      @photo = Photo.new
      flash.now[:alert] = result.errors.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    result = UpdatePhoto.call(photo: @photo, params: photo_params)

    if result.success?
      redirect_to @photo, notice: "Photo updated."
    else
      flash.now[:alert] = result.errors.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    DeletePhoto.call(photo: @photo)
    redirect_to photos_path, notice: "Photo deleted."
  end

  private

  def set_photo
    @photo = Current.user.photos.find(params[:id])
  end

  def photo_params
    params.require(:photo).permit(:file, :title, :description)
  end
end
