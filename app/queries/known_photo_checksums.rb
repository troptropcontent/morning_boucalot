# Of the given Active Storage checksums (base64 MD5), returns the ones the
# owner already has as a photo's file or raw_file. Lets the phone utility
# skip uploading files the server would only reject as duplicates after the
# whole transfer.
class KnownPhotoChecksums
  ATTACHMENT_NAMES = %w[file raw_file].freeze

  def self.call(...) = new(...).call

  def initialize(owner:, checksums:)
    @owner = owner
    @checksums = checksums
  end

  def call
    ActiveStorage::Blob
      .where(checksum: @checksums)
      .joins(:attachments)
      .where(active_storage_attachments: { record_type: "Photo", name: ATTACHMENT_NAMES, record_id: @owner.photos.select(:id) })
      .distinct
      .pluck(:checksum)
  end
end
