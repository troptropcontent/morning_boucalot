require "rails_helper"

RSpec.describe TogglePhotoFavorite do
  describe ".call" do
    it "marks an unfavorited photo as favorited" do
      photo = FactoryBot.create(:photo, favorited: false)
      result = TogglePhotoFavorite.call(photo: photo)
      expect(result).to be_success
      expect(result.data.favorited).to be true
    end

    it "marks a favorited photo as unfavorited" do
      photo = FactoryBot.create(:photo, favorited: true)
      result = TogglePhotoFavorite.call(photo: photo)
      expect(result).to be_success
      expect(result.data.favorited).to be false
    end

    it "persists the change" do
      photo = FactoryBot.create(:photo, favorited: false)
      TogglePhotoFavorite.call(photo: photo)
      expect(photo.reload.favorited).to be true
    end
  end
end
