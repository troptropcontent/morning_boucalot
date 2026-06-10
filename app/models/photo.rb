class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :file
  validates :file, presence: true

  scope :recent, -> { order(taken_at: :desc, created_at: :desc) }

  def thumbnail = file.variant(resize_to_fill: [300, 300])
  def medium = file.variant(resize_to_limit: [800, 600])
  def large = file.variant(resize_to_limit: [2400, 2400])
end
