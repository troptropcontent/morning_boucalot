require "rails_helper"

RSpec.describe Favorite, type: :model do
  subject(:favorite) { FactoryBot.build(:favorite) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:photo) }
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid when the user has already favorited the photo" do
      existing = FactoryBot.create(:favorite)
      duplicate = FactoryBot.build(:favorite, user: existing.user, photo: existing.photo)

      expect(duplicate).not_to be_valid
    end

    it "allows the same photo to be favorited by different users" do
      existing = FactoryBot.create(:favorite)
      other = FactoryBot.build(:favorite, photo: existing.photo)

      expect(other).to be_valid
    end

    it "allows the same user to favorite different photos" do
      existing = FactoryBot.create(:favorite)
      other = FactoryBot.build(:favorite, user: existing.user)

      expect(other).to be_valid
    end
  end
end
