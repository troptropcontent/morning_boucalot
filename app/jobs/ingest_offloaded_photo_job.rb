class IngestOffloadedPhotoJob < ApplicationJob
  queue_as :default

  RAW_EXTENSIONS = %w[raf].freeze
  JPEG_EXTENSIONS = %w[jpg jpeg].freeze

  def perform(file_path)
    return unless File.exist?(file_path)
    return unless within_incoming_dir?(file_path)

    attachment_name = attachment_name_for(file_path)
    return unless attachment_name

    owner = find_owner
    return unless owner

    stem = File.basename(file_path, ".*")
    photo = find_pending_pair(owner, stem, attachment_name) || owner.photos.build(published: false)

    # The actual upload to the storage service happens inside photo.save
    # (has_one_attached defers it via an autosave callback for a new
    # record), so the file handle has to stay open across the save call —
    # not just the attach call — or Active Storage tries to read from an
    # already-closed IO.
    File.open(file_path, "rb") do |io|
      photo.public_send(attachment_name).attach(io: io, filename: File.basename(file_path))

      if PhotoChecksumExists.call(owner: owner, checksum: photo.public_send(attachment_name).blob.checksum, attachment_name: attachment_name, excluding_photo_id: photo.id)
        purge_attachment(photo, attachment_name)
        File.delete(file_path)
        next
      end

      photo.file_size = File.size(file_path) if attachment_name == :file

      if photo.save
        ProcessPhotoJob.perform_later(photo.id) if attachment_name == :file
        File.delete(file_path)
      else
        purge_attachment(photo, attachment_name)
      end
    end
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

  def attachment_name_for(file_path)
    extension = File.extname(file_path).delete_prefix(".").downcase
    return :raw_file if RAW_EXTENSIONS.include?(extension)
    return :file if JPEG_EXTENSIONS.include?(extension)
  end

  def find_owner
    email = ENV["FTP_INGEST_USER_EMAIL"]
    return nil if email.blank?

    User.find_by(email_address: email)
  end

  # The camera sends the JPEG and RAF of one shot as two separate uploads
  # with the same filename stem, in no guaranteed order — so whichever
  # arrives second needs to attach onto the Photo the first one created,
  # not create a sibling record. The review queue is small (a handful of
  # pending shots at a time), so scanning it in Ruby is simpler and safer
  # than a multi-table join across two differently-named attachments.
  def find_pending_pair(owner, stem, missing_name)
    other_name = missing_name == :file ? :raw_file : :file

    owner.photos.unpublished.detect do |photo|
      other = photo.public_send(other_name)
      other.attached? &&
        !photo.public_send(missing_name).attached? &&
        File.basename(other.blob.filename.to_s, ".*") == stem
    end
  end

  def purge_attachment(photo, attachment_name)
    attached = photo.public_send(attachment_name)
    attached.attachment ? attached.purge : attached.blob&.purge
  end
end
