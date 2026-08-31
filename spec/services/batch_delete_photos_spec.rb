require "rails_helper"

RSpec.describe BatchDeletePhotos do
  let(:owner) { FactoryBot.create(:user) }
  let!(:photos) { FactoryBot.create_list(:photo, 3, user: owner) }

  describe ".call" do
    it "destroys all selected photos" do
      expect {
        BatchDeletePhotos.call(owner: owner, photo_ids: photos.map(&:id))
      }.to change(Photo, :count).by(-3)
    end

    it "returns the destroyed photo ids" do
      result = BatchDeletePhotos.call(owner: owner, photo_ids: photos.map(&:id))
      expect(result).to be_success
      expect(result.data).to match_array(photos.map(&:id))
    end

    it "only destroys the selected photos, leaving others untouched" do
      untouched = FactoryBot.create(:photo, user: owner)
      BatchDeletePhotos.call(owner: owner, photo_ids: [ photos.first.id ])
      expect(Photo.exists?(untouched.id)).to be true
      expect(Photo.exists?(photos.first.id)).to be false
    end

    it "scopes to the owner's photos and ignores foreign ids" do
      other_photo = FactoryBot.create(:photo)
      result = BatchDeletePhotos.call(owner: owner, photo_ids: [ other_photo.id ])
      expect(result).to be_failure
      expect(Photo.exists?(other_photo.id)).to be true
    end

    it "fails when photo_ids is empty" do
      result = BatchDeletePhotos.call(owner: owner, photo_ids: [])
      expect(result).to be_failure
      expect(result.errors).to include("No photos selected")
    end

    it "fails when no matching photos are found" do
      result = BatchDeletePhotos.call(owner: owner, photo_ids: [ -1 ])
      expect(result).to be_failure
      expect(result.errors).to include("No matching photos found")
    end
  end
end
