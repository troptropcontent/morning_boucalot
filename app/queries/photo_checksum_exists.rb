# Shared duplicate-detection used by both the manual upload path
# (UploadPhoto) and the FTP offload ingestion path (IngestOffloadedPhotoJob)
# — a camera retrying a transfer, or re-uploading a file already imported,
# shouldn't create a second copy.
class PhotoChecksumExists
  def self.call(...) = new(...).call

  def initialize(owner:, checksum:, attachment_name: :file, excluding_photo_id: nil)
    @owner = owner
    @checksum = checksum
    @attachment_name = attachment_name.to_s
    @excluding_photo_id = excluding_photo_id
  end

  def call
    scope = ActiveStorage::Blob
      .where(checksum: @checksum)
      .joins(:attachments)
      .where(active_storage_attachments: { record_type: "Photo", name: @attachment_name, record_id: @owner.photos.select(:id) })
    scope = scope.where.not(active_storage_attachments: { record_id: @excluding_photo_id }) if @excluding_photo_id
    scope.exists?
  end
end
