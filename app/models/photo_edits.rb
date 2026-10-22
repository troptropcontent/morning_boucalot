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
# Rotation is quarter turns only; `straighten_angle` adds a small free
# angle on top (e.g. levelling a horizon). The transformations hash can't
# hold two `rotate:` keys, so both go into a single `rotate:`, followed by a
# `crop:` to the largest upright rectangle inside the rotated image (to drop
# the empty corners) — merged with the user's own crop, which is drawn on
# that straightened image.
class PhotoEdits
  ROTATIONS = [ 0, 90, 180, 270 ].freeze
  STRAIGHTEN_RANGE = -45..45

  # Pixels shaved off each side of the straightened image: libvips rounds the
  # rotated canvas to whole pixels and blends the image's edge into the empty
  # corners, so a box right on the edge could show a dark fringe.
  STRAIGHTEN_INSET = 2

  attr_reader :rotation, :straighten_angle, :crop, :width, :height

  # `crop` is [x, y, w, h] as fractions (0..1) of the straightened image, or
  # nil. `straighten_angle` is in degrees, clockwise.
  def initialize(rotation: 0, straighten_angle: 0, crop: nil, width: nil, height: nil)
    @rotation = rotation.to_i
    @straighten_angle = straighten_angle.to_f
    @crop = crop
    @width = width
    @height = height
  end

  # Order matters: edits run before any resize/crop-to-fill, so they act on
  # the full-resolution image the user actually sees — and the crop runs
  # after the rotation because it was drawn on the rotated image.
  # `only_rotation: true` gives the image the crop screen draws on: the
  # browser straightens it there, live.
  def transformations(only_rotation: false)
    steps = {}
    if straightened? && !only_rotation
      steps[:rotate] = rotation + straighten_angle
    elsif rotated?
      steps[:rotate] = rotation
    end
    steps[:crop] = crop_pixels if !only_rotation && (cropped? || straightened?)
    steps
  end

  def edited?
    rotated? || straightened? || cropped?
  end

  def rotated?
    !rotation.zero?
  end

  def straightened?
    !straighten_angle.zero?
  end

  def cropped?
    crop.present?
  end

  def dimensions
    cropped? || straightened? ? crop_pixels.last(2) : rotated_dimensions
  end

  private

  def rotated_dimensions
    rotation.in?([ 90, 270 ]) ? [ height, width ] : [ width, height ]
  end

  # [left, top, width, height] of the largest upright rectangle with the
  # image's own proportions that fits inside it once straightened, on the
  # canvas libvips grows to hold the tilted image (centered on it).
  def straightened_area
    image_width, image_height = rotated_dimensions
    return [ 0, 0, image_width, image_height ] unless straightened?

    angle = straighten_angle.abs * Math::PI / 180
    cos, sin = Math.cos(angle), Math.sin(angle)
    canvas_width = image_width * cos + image_height * sin
    canvas_height = image_width * sin + image_height * cos
    scale = [ image_width / canvas_width, image_height / canvas_height ].min
    area_width = [ (image_width * scale).floor - 2 * STRAIGHTEN_INSET, 1 ].max
    area_height = [ (image_height * scale).floor - 2 * STRAIGHTEN_INSET, 1 ].max
    [ ((canvas_width - area_width) / 2).round, ((canvas_height - area_height) / 2).round, area_width, area_height ]
  end

  # Rounded to whole pixels and clamped so rounding can never push the box
  # past the straightened image's edge or collapse it to nothing.
  def crop_pixels
    raise ArgumentError, "Image dimensions are needed to crop" unless width && height

    area_left, area_top, area_width, area_height = straightened_area
    return [ area_left, area_top, area_width, area_height ] unless cropped?

    x, y, w, h = crop
    left = (x * area_width).round.clamp(0, area_width - 1)
    top = (y * area_height).round.clamp(0, area_height - 1)
    [
      area_left + left,
      area_top + top,
      (w * area_width).round.clamp(1, area_width - left),
      (h * area_height).round.clamp(1, area_height - top)
    ]
  end
end
