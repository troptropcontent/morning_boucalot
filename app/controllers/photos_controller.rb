class PhotosController < ApplicationController
  before_action :set_owner
  before_action :require_gallery_owner!, only: %i[new upload create edit update destroy batch batch_destroy]
  before_action :require_gallery_viewer!, only: %i[download_zip]
  before_action :set_photo, only: %i[show edit update destroy favorite]
  before_action :set_filter, only: %i[index show edit]
  allow_unauthenticated_access only: %i[index show]

  def index
    photos = @filter.apply(@owner.photos.with_attached_file.recent)
    @tags = @owner.tags
    @pagy, @photos = pagy(photos, limit: 30)
    @favorited_photo_ids = favorited_photo_ids_for(@photos)
  end

  def show
    photos = @filter.apply(@owner.photos.with_attached_file.recent)
    adjacent = FindAdjacentPhotos.call(photo: @photo, scope: photos).data
    @prev_photo = adjacent[:previous_photo]
    @next_photo = adjacent[:next_photo]
    @favorited_photo_ids = favorited_photo_ids_for([ @photo ])
  end

  def new
    @photo = Photo.new
    @tags = @owner.tags
  end

  def upload
  end

  def create
    result = UploadPhoto.call(user: Current.user, params: photo_params)

    respond_to do |format|
      if result.success?
        format.html { redirect_to user_photo_path(@owner, result.data), notice: "Photo uploaded." }
        format.json { render json: { id: result.data.id }, status: :created }
      elsif result.errors == [ "duplicate" ]
        format.html { redirect_to upload_user_photos_path(@owner), notice: "Photo already exists, skipped." }
        format.json { render json: { status: "duplicate" }, status: :ok }
      else
        format.html do
          @photo = Photo.new
          @tags = @owner.tags
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
            turbo_stream.update("photo_details", partial: "photos/details", locals: { photo: @photo, owner: @owner, favorited: @photo.favorited_by?(Current.user) }),
            turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: "Photo updated.", alert: nil })
          ]
        end
        format.html { redirect_to user_photo_path(@owner, @photo), notice: "Photo updated." }
      else
        format.html do
          flash.now[:alert] = result.errors.join(", ")
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  def batch
    result = BatchTagPhotos.call(
      owner: @owner,
      photo_ids: params[:photo_ids],
      tag_list: params[:tag_list]
    )

    count = result.data&.count
    respond_to do |format|
      if result.success?
        notice = "Tags added to #{count} photo#{"s" unless count == 1}."
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: notice, alert: nil }) }
        format.html { redirect_to user_photos_path(@owner), notice: notice }
      else
        alert = result.errors.join(", ")
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: nil, alert: alert }) }
        format.html { redirect_to user_photos_path(@owner), alert: alert }
      end
    end
  end

  def batch_destroy
    result = BatchDeletePhotos.call(owner: @owner, photo_ids: params[:photo_ids])

    count = result.data&.count
    respond_to do |format|
      if result.success?
        notice = "#{count} photo#{"s" unless count == 1} deleted."
        format.turbo_stream do
          render turbo_stream: [
            *result.data.map { |id| turbo_stream.remove(helpers.dom_id(Photo.new(id: id))) },
            turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: notice, alert: nil })
          ]
        end
        format.html { redirect_to user_photos_path(@owner), notice: notice }
      else
        alert = result.errors.join(", ")
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: nil, alert: alert }) }
        format.html { redirect_to user_photos_path(@owner), alert: alert }
      end
    end
  end

  def favorite
    favorited = TogglePhotoFavorite.call(photo: @photo, user: Current.user).data

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@photo, :favorite_btn),
          partial: "photos/favorite_button",
          locals: { photo: @photo, owner: @owner, favorited: favorited }
        )
      end
      format.html { redirect_back_or_to user_photo_path(@owner, @photo) }
    end
  end

  def download_zip
    result = DownloadPhotos.call(owner: @owner, photo_ids: params[:photo_ids], variant: params[:variant])

    if result.success?
      send_data result.data,
                filename: "photos_#{Date.today}.zip",
                type: "application/zip",
                disposition: "attachment"
    else
      redirect_to user_photos_path(@owner), alert: result.errors.join(", ")
    end
  end

  def destroy
    DeletePhoto.call(photo: @photo)
    redirect_to user_photos_path(@owner), notice: "Photo deleted."
  end

  private

  def set_owner
    @owner = User.find(params[:user_id])
  end

  def set_photo
    @photo = @owner.photos.find(params[:id])
  end

  def set_filter
    @filter = PhotoFilter.new(params: params, user: Current.user)
  end

  def require_gallery_owner!
    head :forbidden unless GalleryPolicy.new(user: Current.user, owner: @owner).owner?
  end

  def require_gallery_viewer!
    head :forbidden unless GalleryPolicy.new(user: Current.user, owner: @owner).viewer?
  end

  def photo_params
    params.require(:photo).permit(:file, :title, :description, :tag_list)
  end

  def favorited_photo_ids_for(photos)
    return [] unless Current.user

    Current.user.favorite_photos.where(id: photos.map(&:id)).ids
  end
end
