class RotatePhoto < ApplicationService
  STEPS = { "clockwise" => 90, "counterclockwise" => 270 }.freeze

  def initialize(photo:, direction:)
    @photo = photo
    @direction = direction.to_s
  end

  def call
    step = STEPS[@direction]
    fail!([ "Unknown rotation direction" ]) unless step
    fail!([ "Only photos with an image file can be rotated" ]) unless @photo.file.attached?

    # Locked so two quick taps both land (0 → 90 → 180) instead of each
    # reading 0 and writing 90. The crop was drawn on the old orientation,
    # so it no longer means anything and is cleared.
    @photo.with_lock do
      rotation = (@photo.rotation + step) % 360
      fail!(@photo.errors.full_messages) unless @photo.update(rotation: rotation, crop_x: nil, crop_y: nil, crop_w: nil, crop_h: nil)
    end
    WarmPhotoVariantsJob.perform_later(@photo.id)

    @photo
  end
end
