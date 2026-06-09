require "rails_helper"

RSpec.describe Photo, type: :model do
  subject(:photo) { FactoryBot.build(:photo) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:album_photos).dependent(:destroy) }
    it { is_expected.to have_many(:albums).through(:album_photos) }
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without a file" do
      photo.file.detach
      expect(photo).not_to be_valid
    end
  end

  describe ".recent" do
    it "orders by taken_at descending, then created_at descending" do
      user = FactoryBot.create(:user)
      old_photo = FactoryBot.create(:photo, user: user, taken_at: 2.days.ago)
      new_photo = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago)

      expect(Photo.recent).to eq([ new_photo, old_photo ])
    end
  end
end
