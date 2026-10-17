require "rails_helper"

RSpec.describe KnownPhotoChecksums do
  let(:user) { FactoryBot.create(:user) }

  it "returns the checksums the owner already has as a file" do
    photo = FactoryBot.create(:photo, user: user)
    checksum = photo.file.blob.checksum

    expect(KnownPhotoChecksums.call(owner: user, checksums: [ checksum, "unknown" ])).to eq([ checksum ])
  end

  it "also matches raw_file checksums" do
    photo = FactoryBot.create(:photo, user: user)
    photo.raw_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/test_raw.raf")), filename: "test_raw.raf")

    expect(KnownPhotoChecksums.call(owner: user, checksums: [ photo.raw_file.blob.checksum ])).to eq([ photo.raw_file.blob.checksum ])
  end

  it "ignores checksums that belong to another user" do
    photo = FactoryBot.create(:photo, user: FactoryBot.create(:user))

    expect(KnownPhotoChecksums.call(owner: user, checksums: [ photo.file.blob.checksum ])).to eq([])
  end

  it "returns an empty list for no checksums" do
    expect(KnownPhotoChecksums.call(owner: user, checksums: [])).to eq([])
  end
end
