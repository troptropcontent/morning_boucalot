# Hands the phone a short-lived S3 URL to PUT a RAF to directly, or tells it
# the RAF is already in the bucket so a rescan doesn't re-send 50MB. The key
# is built server-side from a validated filename -- never from raw client
# input -- so a crafted name can't escape the owner's prefix.
class PresignRafUpload < ApplicationService
  FILENAME_FORMAT = /\A[A-Za-z0-9_-]+\.raf\z/i

  def initialize(owner:, filename:, size:, bucket: RafBucket.new)
    @owner = owner
    @filename = filename.to_s
    @size = size.to_s
    @bucket = bucket
  end

  def call
    fail!([ "filename must be a .raf file" ]) unless @filename.match?(FILENAME_FORMAT)
    fail!([ "size must be a positive integer" ]) unless @size.match?(/\A[1-9]\d*\z/)

    key = RafBucket.key_for(owner: @owner, filename: @filename, size: @size)
    return { already_uploaded: true } if @bucket.exists?(key)

    { already_uploaded: false, url: @bucket.presigned_put_url(key), headers: { "Content-Type" => RafBucket::CONTENT_TYPE } }
  end
end
