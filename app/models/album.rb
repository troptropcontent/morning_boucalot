class Album < ApplicationRecord
  belongs_to :user
  belongs_to :cover_photo, class_name: "Photo", optional: true
  has_many :album_photos, dependent: :destroy
  has_many :photos, through: :album_photos

  validates :title, presence: true
end
