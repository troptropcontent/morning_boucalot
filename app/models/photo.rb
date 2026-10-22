class Photo < ApplicationRecord
  # Not declared as named variants on the attachment: those are static, while
  # every variant here must also carry the photo's own edits (see
  # #image_variant). For an unedited photo the transformations are identical
  # to what the named variants produced, so existing cached variants are
  # reused rather than regenerated.
  VARIANTS = {
    thumbnail: { resize_to_fill: [ 300, 300 ] },
    medium: { resize_to_limit: [ 800, 600 ] },
    large: { resize_to_limit: [ 2400, 2400 ] },
    # Edits only, at full resolution. Generated on first download rather than
    # warmed: full-size files are large and most photos never need one.
    full: { saver: { quality: 95 } }
  }.freeze

  DOWNLOADS = %i[original full large].freeze

  belongs_to :user
  has_one_attached :file
  # The RAF counterpart of a camera-offloaded shot. No variants: raw files
  # aren't readable by image_processing/libvips or EXIFR, so this is stored
  # for download only.
  has_one_attached :raw_file
  has_many :photo_tags, dependent: :destroy
  has_many :tags, through: :photo_tags
  has_many :favorites, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user

  enum :status, { pending: "pending", ready: "ready", failed: "failed" }

  # A manual upload always attaches `file`. An FTP-offloaded shot may land
  # with only `raw_file` if the camera sends the RAF before (or instead of)
  # the JPEG, so at least one of the two is required rather than `file`
  # specifically.
  #
  # TODO: raw-only photos are treated as an error state, but nothing enforces
  # it — they can still be published, and downloads (Photo#download,
  # DownloadPhotos) assume `file` is attached. Either block publishing until
  # the JPEG arrives, or model the RAF separately from the photo (e.g. its own
  # record that a later JPEG gets paired with) so a Photo always has `file`.
  validate :file_or_raw_file_present
  validates :rotation, inclusion: { in: PhotoEdits::ROTATIONS }
  validates :straighten_angle, numericality: { in: PhotoEdits::STRAIGHTEN_RANGE }
  validate :crop_within_image

  # Photos without EXIF data (or non-JPEGs) never get a taken_at from
  # ProcessPhotoJob, so we default it to the upload time. This keeps taken_at
  # always present, which lets `recent` sort on a plain indexed column
  # instead of an expression, and keeps ordering identical between SQLite
  # (dev) and Postgres (prod) — the two engines order NULLs differently.
  before_save { self.taken_at ||= Time.current }

  # `id` is a final tiebreaker so the order is fully deterministic — needed
  # for keyset pagination in FindAdjacentPhotos to work reliably.
  scope :recent, -> { order(taken_at: :desc, created_at: :desc, id: :desc) }
  scope :tagged_with, ->(name) { joins(:tags).where(tags: { name: name.downcase.strip }) }
  scope :favorited_by, ->(user) { joins(:favorites).where(favorites: { user_id: user&.id }) }
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def tag_list
    tags.map(&:name).join(", ")
  end

  def favorited_by?(user)
    user.present? && favorited_by_users.include?(user)
  end

  def edits
    metadata = file.attached? ? file.blob.metadata : {}
    PhotoEdits.new(rotation: rotation, straighten_angle: straighten_angle, crop: crop_box, width: metadata[:width], height: metadata[:height])
  end

  def crop_box
    box = [ crop_x, crop_y, crop_w, crop_h ]
    box if box.all?
  end

  # `only_rotation: true` keeps the quarter turns but not the straightening
  # or crop — the image the crop screen draws on.
  def image_variant(name, only_rotation: false)
    file.variant(edits.transformations(only_rotation: only_rotation).merge(VARIANTS.fetch(name)))
  end

  # What a download of `kind` serves: the stored file when it can go out
  # as-is, a variant when edits or resizing must be applied. :full falls back
  # to the original while there are no edits, since re-encoding would only
  # lose quality.
  def download(kind)
    kind = kind.to_sym
    raise ArgumentError, "Unknown download: #{kind}" unless kind.in?(DOWNLOADS)
    return file.blob if kind == :original || (kind == :full && !edits.edited?)

    image_variant(kind)
  end

  private

  def crop_within_image
    box = [ crop_x, crop_y, crop_w, crop_h ]
    return if box.none?
    return errors.add(:base, "Crop needs a position and a size") unless box.all?

    x, y, w, h = box
    inside = x >= 0 && y >= 0 && w.positive? && h.positive? && x + w <= 1 && y + h <= 1
    errors.add(:base, "Crop must lie within the image") unless inside
  end

  def file_or_raw_file_present
    errors.add(:file, :blank) unless file.attached? || raw_file.attached?
  end
end
