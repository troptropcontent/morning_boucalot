require "rails_helper"

RSpec.describe TogglePhotoFavorite do
  describe ".call" do
    it "favorites a photo the user hasn't favorited yet" do
      photo = FactoryBot.create(:photo)
      user = FactoryBot.create(:user)

      result = TogglePhotoFavorite.call(photo: photo, user: user)

      expect(result).to be_success
      expect(result.data).to be true
      expect(photo.favorited_by?(user)).to be true
    end

    it "unfavorites a photo the user already favorited" do
      photo = FactoryBot.create(:photo)
      user = FactoryBot.create(:user)
      FactoryBot.create(:favorite, photo: photo, user: user)

      result = TogglePhotoFavorite.call(photo: photo, user: user)

      expect(result).to be_success
      expect(result.data).to be false
      expect(photo.favorited_by?(user)).to be false
    end

    it "does not affect other users' favorites of the same photo" do
      photo = FactoryBot.create(:photo)
      user = FactoryBot.create(:user)
      other_user = FactoryBot.create(:user)
      FactoryBot.create(:favorite, photo: photo, user: other_user)

      TogglePhotoFavorite.call(photo: photo, user: user)

      expect(photo.favorited_by?(other_user)).to be true
    end
  end
end
