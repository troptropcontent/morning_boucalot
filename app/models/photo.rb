class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :file do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [300, 300]
    attachable.variant :medium, resize_to_limit: [800, 600]
    attachable.variant :large, resize_to_limit: [2400, 2400]
  end
  has_many :photo_tags, dependent: :destroy
  has_many :tags, through: :photo_tags

  validates :file, presence: true

  scope :recent, -> { order(taken_at: :desc, created_at: :desc) }
  scope :tagged_with, ->(name) { joins(:tags).where(tags: { name: name.downcase.strip }) }
  scope :favorited, -> { where(favorited: true) }

  def tag_list
    tags.map(&:name).join(", ")
  end


end
