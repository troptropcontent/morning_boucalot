class PhotosController < ApplicationController
  before_action :set_photo, only: %i[show edit update destroy]

  def index
    @pagy, @photos = pagy(Current.user.photos.with_attached_file.recent, limit: 30)
  end

  def show
    photo_ids = Current.user.photos.recent.ids
    idx = photo_ids.index(@photo.id)
    @prev_photo_id = photo_ids[idx - 1] if idx&.positive?
    @next_photo_id = photo_ids[idx + 1] if idx && idx < photo_ids.length - 1
  end

  def new
    @photo = Photo.new
  end

  def upload
  end

  def create
    result = UploadPhoto.call(user: Current.user, params: photo_params)

    respond_to do |format|
      if result.success?
        format.html { redirect_to result.data, notice: "Photo uploaded." }
        format.json { render json: { id: result.data.id }, status: :created }
      else
        format.html do
          @photo = Photo.new
          flash.now[:alert] = result.errors.join(", ")
          render :new, status: :unprocessable_entity
        end
        format.json { render json: { errors: result.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    result = UpdatePhoto.call(photo: @photo, params: photo_params)

    respond_to do |format|
      if result.success?
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("photo_details", partial: "photos/details", locals: { photo: @photo }),
            turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: "Photo updated.", alert: nil })
          ]
        end
        format.html { redirect_to @photo, notice: "Photo updated." }
      else
        format.html do
          flash.now[:alert] = result.errors.join(", ")
          render :edit, status: :unprocessable_entity
        end
      end
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
