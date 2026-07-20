require "rails_helper"

RSpec.describe BatchTagPhotos do
  let(:owner) { FactoryBot.create(:user) }
  let(:photos) { FactoryBot.create_list(:photo, 3, user: owner) }

  describe ".call" do
    it "adds tags to all selected photos" do
      result = BatchTagPhotos.call(owner: owner, photo_ids: photos.map(&:id), tag_list: "landscape")
      expect(result).to be_success
      photos.each { |p| expect(p.reload.tags.map(&:name)).to include("landscape") }
    end

    it "merges new tags with existing ones" do
      SyncPhotoTags.call(photo: photos.first, tag_list: "existing")
      BatchTagPhotos.call(owner: owner, photo_ids: [ photos.first.id ], tag_list: "new")
      expect(photos.first.reload.tags.map(&:name)).to contain_exactly("existing", "new")
    end

    it "does not duplicate tags already on a photo" do
      SyncPhotoTags.call(photo: photos.first, tag_list: "landscape")
      BatchTagPhotos.call(owner: owner, photo_ids: [ photos.first.id ], tag_list: "landscape")
      expect(photos.first.reload.tags.map(&:name)).to eq([ "landscape" ])
    end

    it "returns the affected photos" do
      result = BatchTagPhotos.call(owner: owner, photo_ids: photos.map(&:id), tag_list: "travel")
      expect(result.data.map(&:id)).to match_array(photos.map(&:id))
    end

    it "scopes to the owner's photos and ignores foreign ids" do
      other_photo = FactoryBot.create(:photo)
      result = BatchTagPhotos.call(owner: owner, photo_ids: [ other_photo.id ], tag_list: "landscape")
      expect(result).to be_failure
      expect(other_photo.reload.tags).to be_empty
    end

    it "fails when photo_ids is empty" do
      result = BatchTagPhotos.call(owner: owner, photo_ids: [], tag_list: "landscape")
      expect(result).to be_failure
      expect(result.errors).to include("No photos selected")
    end

    it "fails when tag_list is blank" do
      result = BatchTagPhotos.call(owner: owner, photo_ids: photos.map(&:id), tag_list: "")
      expect(result).to be_failure
      expect(result.errors).to include("No tags provided")
    end
  end
end
