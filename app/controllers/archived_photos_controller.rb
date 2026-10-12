class ArchivedPhotosController < ApplicationController
  before_action :set_owner
  before_action :require_gallery_owner!
  before_action :set_photo, only: %i[restore destroy]

  def index
    photos = @owner.photos.archived.with_attached_file.recent
    @pagy, @photos = pagy(photos, limit: 30)
  end

  def restore
    RestorePhoto.call(photo: @photo)
    respond_with_update("Photo restored.")
  end

  def destroy
    DeletePhoto.call(photo: @photo)
    respond_with_update("Photo permanently deleted.")
  end

  def batch_restore
    result = BatchRestorePhotos.call(owner: @owner, photo_ids: params[:photo_ids])
    respond_with_batch(result, "restored")
  end

  def batch_destroy
    result = BatchDeletePhotos.call(owner: @owner, photo_ids: params[:photo_ids])
    respond_with_batch(result, "permanently deleted")
  end

  private

  def set_owner
    @owner = User.find(params[:user_id])
  end

  def set_photo
    @photo = @owner.photos.archived.find(params[:id])
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
      format.html { redirect_to user_archived_photos_path(@owner), notice: notice }
    end
  end

  def respond_with_batch(result, verb)
    count = result.data&.count
    respond_to do |format|
      if result.success?
        notice = "#{count} photo#{"s" unless count == 1} #{verb}."
        format.turbo_stream do
          render turbo_stream: [
            *result.data.map { |id| turbo_stream.remove(helpers.dom_id(Photo.new(id: id))) },
            turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: notice, alert: nil })
          ]
        end
        format.html { redirect_to user_archived_photos_path(@owner), notice: notice }
      else
        alert = result.errors.join(", ")
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: nil, alert: alert }) }
        format.html { redirect_to user_archived_photos_path(@owner), alert: alert }
      end
    end
  end
end
