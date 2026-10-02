class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :file do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [300, 300]
    attachable.variant :medium, resize_to_limit: [800, 600]
    attachable.variant :large, resize_to_limit: [2400, 2400]
  end
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
  validate :file_or_raw_file_present

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

  def tag_list
    tags.map(&:name).join(", ")
  end

  def favorited_by?(user)
    user.present? && favorited_by_users.include?(user)
  end

  private

  def file_or_raw_file_present
    errors.add(:file, :blank) unless file.attached? || raw_file.attached?
  end
end
