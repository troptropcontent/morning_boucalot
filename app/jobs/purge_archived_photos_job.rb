class PurgeArchivedPhotosJob < ApplicationJob
  RETENTION_PERIOD = 60.days

  def perform
    Photo.archived.where(archived_at: ..RETENTION_PERIOD.ago).find_each do |photo|
      DeletePhoto.call(photo: photo)
    end
  end
end
