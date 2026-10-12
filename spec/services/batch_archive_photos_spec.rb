require "rails_helper"

RSpec.describe BatchArchivePhotos do
  let(:owner) { FactoryBot.create(:user) }
  let!(:photos) { FactoryBot.create_list(:photo, 3, user: owner) }

  describe ".call" do
    it "archives all selected photos" do
      BatchArchivePhotos.call(owner: owner, photo_ids: photos.map(&:id))
      expect(photos.map { |p| p.reload.archived_at }).to all(be_present)
    end

    it "returns the archived photo ids" do
      result = BatchArchivePhotos.call(owner: owner, photo_ids: photos.map(&:id))
      expect(result).to be_success
      expect(result.data).to match_array(photos.map(&:id))
    end

    it "only archives the selected photos, leaving others untouched" do
      untouched = FactoryBot.create(:photo, user: owner)
      BatchArchivePhotos.call(owner: owner, photo_ids: [ photos.first.id ])
      expect(untouched.reload.archived_at).to be_nil
    end

    it "scopes to the owner's photos and ignores foreign ids" do
      other_photo = FactoryBot.create(:photo)
      result = BatchArchivePhotos.call(owner: owner, photo_ids: [ other_photo.id ])
      expect(result).to be_failure
      expect(other_photo.reload.archived_at).to be_nil
    end

    it "fails when photo_ids is empty" do
      result = BatchArchivePhotos.call(owner: owner, photo_ids: [])
      expect(result).to be_failure
      expect(result.errors).to include("No photos selected")
    end

    it "fails when no matching photos are found" do
      result = BatchArchivePhotos.call(owner: owner, photo_ids: [ -1 ])
      expect(result).to be_failure
      expect(result.errors).to include("No matching photos found")
    end
  end
end
