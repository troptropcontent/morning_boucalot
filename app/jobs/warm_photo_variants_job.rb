class WarmPhotoVariantsJob < ApplicationJob
  queue_as :default

  # Same reasoning as ProcessPhotoJob: warming is idempotent, so a brief
  # retry window rides out transient disk pressure.
  retry_on Errno::ENOSPC, wait: :polynomially_longer, attempts: 3

  # A newer edit makes this run's variants stale but harmless — that edit
  # enqueues its own warm-up, and Active Storage keys variants by their
  # transformations so nothing gets overwritten.
  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    WarmPhotoVariants.call(photo: photo) if photo
  end
end
