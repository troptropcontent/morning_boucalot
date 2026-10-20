require "zip"

class DownloadPhotos < ApplicationService
  ALLOWED_VARIANTS = Photo::DOWNLOADS

  def initialize(owner:, photo_ids:, variant: :original)
    @owner = owner
    @photo_ids = Array(photo_ids).map(&:to_i).uniq
    @variant = ALLOWED_VARIANTS.include?(variant&.to_sym) ? variant.to_sym : :original
  end

  def call
    fail!([ "No photos selected" ]) if @photo_ids.empty?

    photos = @owner.photos.with_attached_file.where(id: @photo_ids)
    fail!([ "No matching photos found" ]) if photos.empty?

    Zip::OutputStream.write_buffer do |zip|
      name_counts = Hash.new(0)
      photos.each do |photo|
        blob = stored_blob(photo.download(@variant))
        zip.put_next_entry(unique_entry_name(photo, blob, name_counts))
        blob.open { |tmp| zip.write(tmp.read) }
      end
    end.string
  end

  private

  def stored_blob(download)
    download.is_a?(ActiveStorage::Blob) ? download : download.processed.image.blob
  end

  def unique_entry_name(photo, blob, counts)
    ext = File.extname(blob.filename.to_s)
    stem = (photo.title.presence || File.basename(blob.filename.to_s, ext))
               .parameterize(separator: "_")
    stem = "photo_#{photo.id}" if stem.blank?
    base = "#{stem}#{ext}"
    counts[base] += 1
    counts[base] > 1 ? "#{stem}_#{counts[base]}#{ext}" : base
  end
end
