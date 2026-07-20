require "rails_helper"

RSpec.describe Photo, type: :model do
  subject(:photo) { FactoryBot.build(:photo) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:photo_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:photo_tags) }
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without a file" do
      photo.file.detach
      expect(photo).not_to be_valid
    end
  end

  describe "#tag_list" do
    it "returns tags as a comma-separated string" do
      photo.save!
      SyncPhotoTags.call(photo: photo, tag_list: "landscape, travel")
      expect(photo.tag_list).to eq("landscape, travel")
    end
  end

  describe ".tagged_with" do
    it "returns photos with the given tag" do
      user = FactoryBot.create(:user)
      tagged = FactoryBot.create(:photo, user: user)
      untagged = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: tagged, tag_list: "landscape")
      SyncPhotoTags.call(photo: untagged, tag_list: "portrait")

      expect(Photo.tagged_with("landscape")).to include(tagged)
      expect(Photo.tagged_with("landscape")).not_to include(untagged)
    end

    it "is case-insensitive" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: photo, tag_list: "landscape")

      expect(Photo.tagged_with("Landscape")).to include(photo)
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
