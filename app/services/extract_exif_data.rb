require "exifr/jpeg"

class ExtractExifData
  def self.call(file_path) = new(file_path).call

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    exif = EXIFR::JPEG.new(@file_path)
    return {} unless exif.exif?

    {
      taken_at: exif.date_time_original,
      camera_model: [ exif.make, exif.model ].compact.join(" ").presence,
      focal_length: exif.focal_length&.to_f,
      aperture: exif.f_number&.to_f,
      iso: exif.iso_speed_ratings,
      shutter_speed: format_shutter_speed(exif.exposure_time),
      width: exif.width,
      height: exif.height
    }.compact
  rescue EXIFR::MalformedJPEG, StandardError
    {}
  end

  private

  def format_shutter_speed(exposure_time)
    return nil unless exposure_time

    if exposure_time.to_f < 1
      "1/#{(1 / exposure_time.to_f).round}"
    else
      "#{exposure_time.to_f.round(1)}s"
    end
  end
end
