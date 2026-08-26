require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { FactoryBot.build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:photos) }
    it { is_expected.to have_many(:favorites).dependent(:destroy) }
    it { is_expected.to have_many(:favorite_photos).through(:favorites).source(:photo) }
    it { is_expected.to have_many(:tags).through(:photos) }
  end

  describe "#tags" do
    let(:user) { FactoryBot.create(:user) }
    let(:other_user) { FactoryBot.create(:user) }

    it "returns each tag once even when attached to several of the user's photos, alphabetically" do
      landscape = FactoryBot.create(:photo, user: user)
      travel = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: landscape, tag_list: "landscape, nature")
      SyncPhotoTags.call(photo: travel, tag_list: "nature, travel")

      expect(user.tags.map(&:name)).to eq(%w[landscape nature travel])
    end

    it "excludes tags belonging only to another user's photos" do
      other_photo = FactoryBot.create(:photo, user: other_user)
      SyncPhotoTags.call(photo: other_photo, tag_list: "landscape")

      expect(user.tags).to be_empty
    end
  end

  describe "validations" do
    it { is_expected.to be_valid }
    it { is_expected.to have_secure_password }
  end

  describe "role" do
    it "defaults to member" do
      expect(User.new).to be_member
    end

    it "is invalid without a password when member" do
      user = FactoryBot.build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it "is invalid when password confirmation does not match" do
      user = FactoryBot.build(:user, password: "password123", password_confirmation: "nope")
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it "is invalid with a password longer than bcrypt's 72-byte limit" do
      user = FactoryBot.build(:user, password: "a" * 73)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too long")
    end

    it "stays valid on update without resupplying the password" do
      user = FactoryBot.create(:user)
      user.email_address = "changed@example.com"
      expect(user).to be_valid
    end

    it "is valid without a password when guest" do
      guest = FactoryBot.build(:user, :guest)
      expect(guest).to be_valid
    end

    it "cannot authenticate a guest by password" do
      guest = FactoryBot.create(:user, :guest)
      expect(guest.authenticate("anything")).to be false
    end
  end

  describe "email normalization" do
    it "strips and downcases the email address" do
      user = FactoryBot.create(:user, email_address: "  TEST@EXAMPLE.COM  ")
      expect(user.email_address).to eq("test@example.com")
    end
  end
end
