require "rails_helper"

RSpec.describe AlbumPhoto, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:album) }
    it { is_expected.to belong_to(:photo) }
  end

  describe "uniqueness" do
    it "prevents duplicate photo in the same album" do
      album_photo = FactoryBot.create(:album_photo)
      duplicate = FactoryBot.build(:album_photo, album: album_photo.album, photo: album_photo.photo)
      expect(duplicate).not_to be_valid
    end
  end
end
