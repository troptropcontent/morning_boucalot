require "rails_helper"

RSpec.describe RemovePhotoFromAlbum do
  describe ".call" do
    it "removes the album_photo" do
      album_photo = FactoryBot.create(:album_photo)
      expect {
        RemovePhotoFromAlbum.call(album_photo: album_photo)
      }.to change(AlbumPhoto, :count).by(-1)
    end

    it "returns a successful result" do
      album_photo = FactoryBot.create(:album_photo)
      result = RemovePhotoFromAlbum.call(album_photo: album_photo)
      expect(result).to be_success
    end
  end
end
