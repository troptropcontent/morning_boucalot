require "zip"

class DownloadPhotos < ApplicationService
  ALLOWED_VARIANTS = %i[original large].freeze

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
        entry_name = unique_entry_name(photo, name_counts)
        zip.put_next_entry(entry_name)
        open_file(photo) { |tmp| zip.write(tmp.read) }
      end
    end.string
  end

  private

  def open_file(photo, &block)
    if @variant == :original
      photo.file.blob.open(&block)
    else
      photo.file.variant(@variant).processed.image.blob.open(&block)
    end
  end

  def unique_entry_name(photo, counts)
    blob = photo.file.blob
    ext = File.extname(blob.filename.to_s)
    stem = (photo.title.presence || File.basename(blob.filename.to_s, ext))
               .parameterize(separator: "_")
    stem = "photo_#{photo.id}" if stem.blank?
    base = "#{stem}#{ext}"
    counts[base] += 1
    counts[base] > 1 ? "#{stem}_#{counts[base]}#{ext}" : base
  end
end
