# Links one RAF already sitting in the bucket to the photo it belongs to as
# `raw_file`, without moving any bytes: the blob is built around the existing
# S3 key, and its checksum comes from the ETag (the MD5 hex for a single-part
# PUT, which is what the phone does). Returns nil when there is nothing to do
# yet -- e.g. the matching JPEG hasn't been offloaded -- so a later run retries.
class AttachRafFromBucket < ApplicationService
  def initialize(key:, size:, etag:)
    @key = key
    @size = size
    @etag = etag
  end

  def call
    return if ActiveStorage::Blob.exists?(key: @key)
    return unless @etag.match?(/\A\h{32}\z/) # multipart ETags aren't an MD5

    _prefix, owner_id, _size, filename = @key.split("/", 4)
    photo = find_photo(owner_id, File.basename(filename.to_s, ".*"))
    return unless photo

    # One transaction so a failed attach can't leave a blob behind: the
    # exists? guard above would then skip this key on every later run.
    ActiveRecord::Base.transaction do
      blob = ActiveStorage::Blob.create!(
        key: @key, filename: filename, byte_size: @size, content_type: RafBucket::CONTENT_TYPE,
        checksum: Base64.strict_encode64([ @etag ].pack("H*")),
        service_name: ActiveStorage::Blob.service.name, metadata: { identified: true, analyzed: true }
      )
      photo.raw_file.attach(blob) || raise(ActiveRecord::Rollback)
      photo
    end
  end

  private

  def find_photo(owner_id, stem)
    Photo.where(user_id: owner_id).where.missing(:raw_file_attachment)
         .joins(file_attachment: :blob)
         .find_by("active_storage_blobs.filename LIKE ? ESCAPE '\\'", "#{ActiveRecord::Base.sanitize_sql_like(stem)}.%")
  end
end
