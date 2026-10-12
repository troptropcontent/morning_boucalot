class BatchRestorePhotos < ApplicationService
  def initialize(owner:, photo_ids:)
    @owner = owner
    @photo_ids = Array(photo_ids).map(&:to_i).uniq
  end

  def call
    fail!([ "No photos selected" ]) if @photo_ids.empty?

    photos = @owner.photos.archived.where(id: @photo_ids)
    fail!([ "No matching photos found" ]) if photos.empty?

    ids = photos.pluck(:id)
    photos.update_all(archived_at: nil)

    ids
  end
end
