# Nightly sweep: attach RAFs the phone uploaded straight to S3 to their photos.
class AttachRafsJob < ApplicationJob
  class PartialFailure < StandardError; end

  def perform(bucket: RafBucket.new)
    failures = {}

    bucket.each_object do |key, size, etag|
      AttachRafFromBucket.call(key: key, size: size, etag: etag)
    rescue StandardError => e
      # One bad object must not block the rest of the night's RAFs, but it
      # must not pass silently either: it's raised below, after the sweep.
      failures[key] = e
    end

    return if failures.empty?

    failures.each { |key, e| Rails.error.report(e, handled: true, context: { key: key }) }
    raise PartialFailure, "#{failures.size} RAF(s) failed to attach: #{failures.keys.join(', ')}"
  end
end
