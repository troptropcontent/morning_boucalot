class OffloadedPhotosController < ApplicationController
  before_action :set_owner
  before_action :require_gallery_owner!
  before_action :set_photo, only: %i[show publish discard]

  def index
    photos = @owner.photos.unpublished.with_attached_file.with_attached_raw_file.recent
    @pagy, @photos = pagy(photos, limit: 30)
  end

  def show
    adjacent = FindAdjacentPhotos.call(photo: @photo, scope: unpublished_photos).data
    @previous_photo = adjacent[:previous_photo]
    @next_photo = adjacent[:next_photo]
  end

  def publish
    next_photo = next_unpublished_photo
    PublishOffloadedPhoto.call(photo: @photo)
    respond_with_update("Photo published.", next_photo)
  end

  def discard
    next_photo = next_unpublished_photo
    DeletePhoto.call(photo: @photo)
    respond_with_update("Photo discarded.", next_photo)
  end

  private

  def set_owner
    @owner = User.find(params[:user_id])
  end

  def set_photo
    @photo = @owner.photos.unpublished.with_attached_file.with_attached_raw_file.find(params[:id])
  end

  def require_gallery_owner!
    head :forbidden unless GalleryPolicy.new(user: Current.user, owner: @owner).owner?
  end

  def unpublished_photos
    @owner.photos.unpublished.with_attached_file.with_attached_raw_file.recent
  end

  def next_unpublished_photo
    FindAdjacentPhotos.call(photo: @photo, scope: unpublished_photos).data[:next_photo]
  end

  def next_update_destination(next_photo)
    return user_offloaded_photo_path(@owner, next_photo) if next_photo

    user_offloaded_photos_path(@owner)
  end

  # Publish/Discard forms always carry a turbo-stream Accept header (Turbo adds
  # it to every non-GET form submission, regardless of data-turbo-stream) — so
  # the only way to get a real redirect for the full-page viewer's buttons is
  # to not offer a turbo_stream format at all for that request. The `navigate`
  # param (set by _actions.html.erb when rendered on the show page) signals that.
  def respond_with_update(notice, next_photo = nil)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: card_removal_stream(notice) } unless params[:navigate]
      format.html { redirect_to next_update_destination(next_photo), notice: notice }
    end
  end

  def card_removal_stream(notice)
    [
      turbo_stream.remove(helpers.dom_id(@photo)),
      turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: notice, alert: nil })
    ]
  end
end
