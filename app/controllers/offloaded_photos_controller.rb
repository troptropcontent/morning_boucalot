class OffloadedPhotosController < ApplicationController
  before_action :set_owner
  before_action :require_gallery_owner!
  before_action :set_photo, only: %i[publish discard]

  def index
    @photos = @owner.photos.unpublished.with_attached_file.with_attached_raw_file.recent
  end

  def publish
    PublishOffloadedPhoto.call(photo: @photo)
    respond_with_update("Photo published.")
  end

  def discard
    DeletePhoto.call(photo: @photo)
    respond_with_update("Photo discarded.")
  end

  private

  def set_owner
    @owner = User.find(params[:user_id])
  end

  def set_photo
    @photo = @owner.photos.unpublished.find(params[:id])
  end

  def require_gallery_owner!
    head :forbidden unless GalleryPolicy.new(user: Current.user, owner: @owner).owner?
  end

  def respond_with_update(notice)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@photo)),
          turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: notice, alert: nil })
        ]
      end
      format.html { redirect_to user_offloaded_photos_path(@owner), notice: notice }
    end
  end
end
