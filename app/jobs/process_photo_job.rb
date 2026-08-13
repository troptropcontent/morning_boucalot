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
    # This broadcasts to every client subscribed to the photo's stream, so
    # there's no single viewer to compute a favorited state for. The owner
    # watching their own upload finish processing is the only realistic
    # subscriber at this point, so we render from their perspective.
    Turbo::StreamsChannel.broadcast_update_to(
      photo,
      target: "photo_details",
      partial: "photos/details",
      locals: { photo: photo, owner: photo.user, favorited: photo.favorited_by?(photo.user) }
    )
  end

  def jpeg?(content_type)
    content_type.in?(%w[image/jpeg image/jpg])
  end
end
