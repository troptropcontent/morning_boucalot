# The non-destructive edits a user has made to a photo. The original file is
# never re-encoded: these transformations are prepended to every variant
# instead, and since Active Storage keys variants by a digest of their
# transformations, each edit state gets its own cached variants for free.
#
# `width`/`height` are the original image's dimensions as displayed, i.e.
# after its EXIF orientation is applied (Active Storage's analyzer reports
# them that way, and libvips auto-rotates before any of these steps run).
# Edited dimensions are computed from them rather than stored.
#
# Rotation is quarter turns only. Free-angle straightening (e.g. levelling a
# horizon) belongs in a separate attribute rather than widening `rotation`:
# the transformations hash can't hold two `rotate:` keys, so it would emit a
# single `rotate: rotation + straighten_angle` followed by a `crop:` to the
# largest upright rectangle inside the rotated image (to drop the empty
# corners), and #dimensions would return that crop's size.
class PhotoEdits
  ROTATIONS = [ 0, 90, 180, 270 ].freeze

  attr_reader :rotation, :crop, :width, :height

  # `crop` is [x, y, w, h] as fractions (0..1) of the rotated image, or nil.
  def initialize(rotation: 0, crop: nil, width: nil, height: nil)
    @rotation = rotation.to_i
    @crop = crop
    @width = width
    @height = height
  end

  # Order matters: edits run before any resize/crop-to-fill, so they act on
  # the full-resolution image the user actually sees — and the crop runs
  # after the rotation because it was drawn on the rotated image.
  # `include_crop: false` gives the image the crop is drawn on.
  def transformations(include_crop: true)
    steps = {}
    steps[:rotate] = rotation if rotated?
    steps[:crop] = crop_pixels if include_crop && cropped?
    steps
  end

  def edited?
    rotated? || cropped?
  end

  def rotated?
    !rotation.zero?
  end

  def cropped?
    crop.present?
  end

  def dimensions
    cropped? ? crop_pixels.last(2) : rotated_dimensions
  end

  private

  def rotated_dimensions
    rotation.in?([ 90, 270 ]) ? [ height, width ] : [ width, height ]
  end

  # Rounded to whole pixels and clamped so rounding can never push the box
  # past the image's edge or collapse it to nothing.
  def crop_pixels
    raise ArgumentError, "Image dimensions are needed to crop" unless width && height

    image_width, image_height = rotated_dimensions
    x, y, w, h = crop
    left = (x * image_width).round.clamp(0, image_width - 1)
    top = (y * image_height).round.clamp(0, image_height - 1)
    [
      left,
      top,
      (w * image_width).round.clamp(1, image_width - left),
      (h * image_height).round.clamp(1, image_height - top)
    ]
  end
end
