require "rails_helper"

RSpec.describe PhotoChecksumExists do
  describe ".call" do
    it "is true when the owner already has a photo with that file checksum" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo, user: user)

      expect(PhotoChecksumExists.call(owner: user, checksum: photo.file.blob.checksum)).to be true
    end

    it "is false for a checksum the owner has never uploaded" do
      user = FactoryBot.create(:user)
      FactoryBot.create(:photo, user: user)

      expect(PhotoChecksumExists.call(owner: user, checksum: "does-not-exist")).to be false
    end

    it "is false when the matching checksum belongs to a different user" do
      owner = FactoryBot.create(:user)
      other_user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo, user: other_user)

      expect(PhotoChecksumExists.call(owner: owner, checksum: photo.file.blob.checksum)).to be false
    end

    it "checks the given attachment_name rather than always file" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo, user: user)
      photo.raw_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/test_raw.raf")), filename: "test_raw.raf")

      expect(PhotoChecksumExists.call(owner: user, checksum: photo.raw_file.blob.checksum, attachment_name: :raw_file)).to be true
      expect(PhotoChecksumExists.call(owner: user, checksum: photo.raw_file.blob.checksum, attachment_name: :file)).to be false
    end
  end
end
