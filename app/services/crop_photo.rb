class CropPhoto < ApplicationService
  # `box` holds x, y, w and h as fractions (0..1) of the rotated image, as
  # drawn on the crop screen. A box covering the whole image clears the crop.
  def initialize(photo:, box:)
    @photo = photo
    @box = box.to_h.symbolize_keys
  end

  def call
    fail!([ "Only photos with an image file can be cropped" ]) unless @photo.file.attached?

    x, y, w, h = normalized_box
    fail!([ "Crop is missing or invalid" ]) unless x

    # The crop is turned into pixels from the analyzed dimensions; analysis
    # normally ran right after upload, this only covers the gap before it.
    @photo.file.blob.analyze unless @photo.file.blob.analyzed?

    crop = whole_image?(x, y, w, h) ? [ nil ] * 4 : [ x, y, w, h ]
    fail!(@photo.errors.full_messages) unless @photo.update(%i[crop_x crop_y crop_w crop_h].zip(crop).to_h)
    WarmPhotoVariantsJob.perform_later(@photo.id)

    @photo
  end

  private

  # Values come from the browser, so they're clamped into the image here:
  # float noise like 1.0000001 shouldn't make an otherwise fine crop fail.
  # Rounded to the column's scale first, so the clamp holds once stored.
  def normalized_box
    values = %i[x y w h].map { |key| Float(@box[key], exception: false) }
    return unless values.all? { |value| value&.finite? }

    x, y, w, h = values.map { |value| value.clamp(0.0, 1.0).round(6) }
    w = [ w, (1 - x).round(6) ].min
    h = [ h, (1 - y).round(6) ].min
    [ x, y, w, h ] if w.positive? && h.positive?
  end

  def whole_image?(x, y, w, h)
    x.zero? && y.zero? && w == 1 && h == 1
  end
end
