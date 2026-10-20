# Generates the variants every page needs up front, so the first visitor
# after an upload or an edit doesn't pay for libvips on a full-size image.
class WarmPhotoVariants < ApplicationService
  VARIANTS = %i[thumbnail medium large].freeze

  def initialize(photo:)
    @photo = photo
  end

  def call
    return @photo unless @photo.file.attached?

    VARIANTS.each { |name| @photo.image_variant(name).processed }
    @photo
  end
end
