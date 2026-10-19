# Thin wrapper over the S3 bucket Active Storage already uses, for RAFs the
# phone PUTs straight to S3 (bypassing Rails, and the MD5 Active Storage's own
# direct upload would demand). Keys are `rafs/<owner_id>/<size>/<FILENAME>`:
# the size segment keeps a wrapped frame counter (DSCF9999 -> DSCF0001) or a
# second card from silently overwriting an older RAF that a photo's blob
# already points at.
class RafBucket
  PREFIX = "rafs/".freeze
  CONTENT_TYPE = "application/octet-stream".freeze
  URL_TTL = 30.minutes

  def self.key_for(owner:, filename:, size:)
    "#{PREFIX}#{owner.id}/#{size}/#{filename}"
  end

  def initialize(bucket: ActiveStorage::Blob.service.bucket)
    @bucket = bucket
  end

  def presigned_put_url(key)
    @bucket.object(key).presigned_url(:put, expires_in: URL_TTL.to_i, content_type: CONTENT_TYPE)
  end

  def exists?(key)
    @bucket.object(key).exists?
  end

  # Yields [key, size, etag] for every object under the RAF prefix.
  def each_object
    @bucket.objects(prefix: PREFIX).each do |summary|
      yield summary.key, summary.size, summary.etag.to_s.delete('"')
    end
  end
end
