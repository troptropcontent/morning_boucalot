class ProcessPhotoJob < ApplicationJob
  queue_as :default

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo&.file&.attached?
    
    
    extract_exif(photo)
    warm_variants(photo)
    photo.ready!

    broadcast_details(photo)
  rescue => e
    photo&.failed!
    raise
  end

  private

  def extract_exif(photo)
    return unless jpeg?(photo.file.content_type)

    photo.file.open do |tempfile|
      exif = ExtractExifData.call(tempfile.path)
      photo.update_columns(exif) if exif.any?
    end
  end

  def warm_variants(photo)
    %i[thumbnail medium large].each do |variant|
      photo.file.variant(variant).processed
    end
  end

  def broadcast_details(photo)
    Turbo::StreamsChannel.broadcast_update_to(
      photo,
      target: "photo_details",
      partial: "photos/details",
      locals: { photo: photo, owner: photo.user, current_user: photo.user }
    )
  end

  def jpeg?(content_type)
    content_type.in?(%w[image/jpeg image/jpg])
  end
end
