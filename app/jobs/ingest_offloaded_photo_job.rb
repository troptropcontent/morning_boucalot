class IngestOffloadedPhotoJob < ApplicationJob
  queue_as :default

  # The JPEG and RAF of one shot share a filename stem and are uploaded as
  # separate FTP transfers, so two worker threads can end up processing them
  # at the same time. That race let find_pending_pair miss its sibling
  # (queried before the other's photo.save committed) and let the same
  # still-present file be re-scanned and ingested twice before the first
  # attempt finished and deleted it. Serializing by stem fixes both: only
  # one job per shot filename runs at a time.
  limits_concurrency to: 1, key: ->(file_path) { File.basename(file_path, ".*") }

  def perform(file_path)
    return unless File.exist?(file_path)
    return unless within_incoming_dir?(file_path)

    owner = OffloadIngestOwner.find
    return unless owner

    # The actual upload to the storage service happens inside photo.save
    # (has_one_attached defers it via an autosave callback for a new
    # record), so the file handle has to stay open across the save call —
    # not just the attach call — or Active Storage tries to read from an
    # already-closed IO. IngestOffloadedPhotoFile's result (success, failure,
    # or duplicate) doesn't change what happens next: the source file is
    # done with either way, so it's always removed from the incoming dir
    # once ingestion has run.
    File.open(file_path, "rb") do |io|
      IngestOffloadedPhotoFile.call(owner: owner, filename: File.basename(file_path), io: io)
    end

    File.delete(file_path)
  end

  private

  # Sanity check before File.open/File.delete touch an arbitrary path —
  # cheap insurance against ever acting outside the incoming dir, even
  # though the only caller today (ScanFtpIncomingJob) already only lists
  # files from inside it.
  def within_incoming_dir?(file_path)
    incoming_dir = ENV["FTP_INCOMING_DIR"]
    return false if incoming_dir.blank?

    File.realpath(file_path).start_with?("#{File.realdirpath(incoming_dir)}#{File::SEPARATOR}")
  end
end
