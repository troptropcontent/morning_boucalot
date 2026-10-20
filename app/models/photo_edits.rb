# The non-destructive edits a user has made to a photo. The original file is
# never re-encoded: these transformations are prepended to every variant
# instead, and since Active Storage keys variants by a digest of their
# transformations, each edit state gets its own cached variants for free.
#
# `width`/`height` are the original file's dimensions (ProcessPhotoJob
# re-derives them from EXIF on every run), so the edited dimensions are
# computed here rather than stored.
#
# Rotation is quarter turns only. Free-angle straightening (e.g. levelling a
# horizon) belongs in a separate attribute rather than widening `rotation`:
# the transformations hash can't hold two `rotate:` keys, so it would emit a
# single `rotate: rotation + straighten_angle` followed by a `crop:` to the
# largest upright rectangle inside the rotated image (to drop the empty
# corners), and #dimensions would return that crop's size.
class PhotoEdits
  ROTATIONS = [ 0, 90, 180, 270 ].freeze

  attr_reader :rotation, :width, :height

  def initialize(rotation: 0, width: nil, height: nil)
    @rotation = rotation.to_i
    @width = width
    @height = height
  end

  # Order matters: edits run before any resize/crop-to-fill, so they act on
  # the full-resolution image the user actually sees.
  def transformations
    edited? ? { rotate: rotation } : {}
  end

  def edited?
    !rotation.zero?
  end

  def dimensions
    rotation.in?([ 90, 270 ]) ? [ height, width ] : [ width, height ]
  end
end
