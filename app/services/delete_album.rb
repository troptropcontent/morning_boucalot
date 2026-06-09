class DeleteAlbum < ApplicationService
  def initialize(album:)
    @album = album
  end

  def call
    @album.destroy
  end
end
