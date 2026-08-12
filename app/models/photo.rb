class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :file do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [300, 300]
    attachable.variant :medium, resize_to_limit: [800, 600]
    attachable.variant :large, resize_to_limit: [2400, 2400]
  end
  has_many :photo_tags, dependent: :destroy
  has_many :tags, through: :photo_tags

  enum :status, { pending: "pending", ready: "ready", failed: "failed" }

  validates :file, presence: true

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
  scope :favorited, -> { where(favorited: true) }

  def tag_list
    tags.map(&:name).join(", ")
  end


end
