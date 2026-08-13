require "rails_helper"

RSpec.describe Photo, type: :model do
  subject(:photo) { FactoryBot.build(:photo) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:photo_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:photo_tags) }
    it { is_expected.to have_many(:favorites).dependent(:destroy) }
    it { is_expected.to have_many(:favorited_by_users).through(:favorites).source(:user) }
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

  describe ".favorited_by" do
    it "returns only photos favorited by the given user" do
      user = FactoryBot.create(:user)
      viewer = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      not_fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: viewer, photo: fav)

      expect(Photo.favorited_by(viewer)).to include(fav)
      expect(Photo.favorited_by(viewer)).not_to include(not_fav)
    end

    it "does not return another user's favorites" do
      user = FactoryBot.create(:user)
      other_user = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: other_user, photo: fav)

      expect(Photo.favorited_by(user)).not_to include(fav)
    end

    it "returns none when no user is given" do
      user = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: user, photo: fav)

      expect(Photo.favorited_by(nil)).to be_empty
    end
  end

  describe "#favorited_by?" do
    it "is true once the given user has favorited the photo" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo)
      FactoryBot.create(:favorite, user: user, photo: photo)

      expect(photo.favorited_by?(user)).to be true
    end

    it "is false for a user who hasn't favorited the photo" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo)

      expect(photo.favorited_by?(user)).to be false
    end

    it "is false when no user is given" do
      photo = FactoryBot.create(:photo)

      expect(photo.favorited_by?(nil)).to be false
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

  describe "taken_at defaulting" do
    it "defaults taken_at to now when not provided" do
      photo = FactoryBot.build(:photo, taken_at: nil)

      expect { photo.save! }.to change(photo, :taken_at).from(nil)
      expect(photo.taken_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not override an explicitly set taken_at" do
      taken_at = 3.days.ago
      photo = FactoryBot.create(:photo, taken_at: taken_at)

      expect(photo.taken_at).to be_within(1.second).of(taken_at)
    end
  end
end
