# Shared by IngestOffloadedPhotoJob (FTP polling, reads a file off disk) and
# OffloadUploadsController (HTTPS upload, reads an uploaded tempfile) — both
# just hand this an IO and let it do the pairing/dedupe/attach work. Neither
# caller cares where the bytes came from, only whether a Photo got created.
class IngestOffloadedPhotoFile < ApplicationService
  RAW_EXTENSIONS = %w[raf].freeze
  JPEG_EXTENSIONS = %w[jpg jpeg].freeze

  def initialize(owner:, filename:, io:)
    @owner = owner
    @filename = filename
    @io = io
  end

  def call
    attachment_name = attachment_name_for(@filename)
    fail!([ "unsupported file type" ]) unless attachment_name

    stem = File.basename(@filename, ".*")
    photo = find_pending_pair(stem, attachment_name) || @owner.photos.build(published: false)

    photo.public_send(attachment_name).attach(**attach_options(attachment_name))

    if PhotoChecksumExists.call(owner: @owner, checksum: photo.public_send(attachment_name).blob.checksum, attachment_name: attachment_name, excluding_photo_id: photo.id)
      purge_attachment(photo, attachment_name)
      fail!([ "duplicate" ])
    end

    photo.file_size = @io.size if attachment_name == :file

    unless photo.save
      purge_attachment(photo, attachment_name)
      fail!(photo.errors.full_messages)
    end

    ProcessPhotoJob.perform_later(photo.id) if attachment_name == :file

    photo
  end

  private

  # RAF is TIFF-based internally, which fools Active Storage's content-type
  # sniffing into tagging it as an image — triggering a libvips analysis job
  # that downloads the whole raw file to local disk just to fail (vips can't
  # actually decode RAF). Forcing a generic type and skipping sniffing
  # (identify: false) avoids that entirely.
  def attach_options(attachment_name)
    options = { io: @io, filename: File.basename(@filename) }
    options.merge!(content_type: "application/octet-stream", identify: false) if attachment_name == :raw_file
    options
  end

  def attachment_name_for(filename)
    extension = File.extname(filename).delete_prefix(".").downcase
    return :raw_file if RAW_EXTENSIONS.include?(extension)
    return :file if JPEG_EXTENSIONS.include?(extension)
  end

  # The JPEG and RAF of one shot can arrive as two separate uploads with the
  # same filename stem, in no guaranteed order — so whichever arrives second
  # needs to attach onto the Photo the first one created, not create a
  # sibling record. The review queue is small (a handful of pending shots at
  # a time), so scanning it in Ruby is simpler and safer than a multi-table
  # join across two differently-named attachments.
  def find_pending_pair(stem, missing_name)
    other_name = missing_name == :file ? :raw_file : :file

    @owner.photos.unpublished.detect do |photo|
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
