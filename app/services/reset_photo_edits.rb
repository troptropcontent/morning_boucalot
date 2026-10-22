class ResetPhotoEdits < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    fail!(@photo.errors.full_messages) unless @photo.update(rotation: 0, straighten_angle: 0, crop_x: nil, crop_y: nil, crop_w: nil, crop_h: nil)
    WarmPhotoVariantsJob.perform_later(@photo.id)

    @photo
  end
end
