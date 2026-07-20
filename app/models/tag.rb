class Tag < ApplicationRecord
  has_many :photo_tags, dependent: :destroy
  has_many :photos, through: :photo_tags

  normalizes :name, with: ->(name) { name.strip.downcase }

  validates :name, presence: true, uniqueness: true
end
