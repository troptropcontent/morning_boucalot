require "rails_helper"

RSpec.describe AddPhotoToAlbum do
  let(:user) { FactoryBot.create(:user) }
  let(:album) { FactoryBot.create(:album, user: user) }
  let(:photo) { FactoryBot.create(:photo, user: user) }

  describe ".call" do
    it "adds the photo to the album" do
      expect {
        AddPhotoToAlbum.call(album: album, photo: photo)
      }.to change { album.photos.count }.by(1)
    end

    it "returns a successful result" do
      result = AddPhotoToAlbum.call(album: album, photo: photo)
      expect(result).to be_success
    end

    it "fails if photo is already in the album" do
      AddPhotoToAlbum.call(album: album, photo: photo)
      result = AddPhotoToAlbum.call(album: album, photo: photo)
      expect(result).to be_failure
    end
  end
end
