class AlbumPhoto < ApplicationRecord
  belongs_to :album
  belongs_to :photo

  validates :photo_id, uniqueness: { scope: :album_id }
end
