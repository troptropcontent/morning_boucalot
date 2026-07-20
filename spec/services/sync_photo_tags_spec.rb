require "rails_helper"

RSpec.describe SyncPhotoTags do
  let(:photo) { FactoryBot.create(:photo) }

  describe ".call" do
    it "assigns tags from a comma-separated string" do
      result = SyncPhotoTags.call(photo: photo, tag_list: "landscape, travel")
      expect(result.data.tags.map(&:name)).to contain_exactly("landscape", "travel")
    end

    it "normalizes tags to lowercase" do
      SyncPhotoTags.call(photo: photo, tag_list: "Landscape, TRAVEL")
      expect(photo.tags.map(&:name)).to contain_exactly("landscape", "travel")
    end

    it "deduplicates tags after normalization" do
      SyncPhotoTags.call(photo: photo, tag_list: "Travel, travel, TRAVEL")
      expect(photo.tags.map(&:name)).to eq([ "travel" ])
    end

    it "clears tags when given an empty string" do
      photo.tags << FactoryBot.create(:tag, name: "landscape")
      SyncPhotoTags.call(photo: photo, tag_list: "")
      expect(photo.tags.reload).to be_empty
    end

    it "reuses existing tags" do
      existing = FactoryBot.create(:tag, name: "landscape")
      SyncPhotoTags.call(photo: photo, tag_list: "landscape")
      expect(Tag.count).to eq(1)
      expect(photo.tags).to include(existing)
    end

    it "replaces existing tags" do
      photo.tags << FactoryBot.create(:tag, name: "old")
      SyncPhotoTags.call(photo: photo, tag_list: "new")
      expect(photo.tags.map(&:name)).to eq([ "new" ])
    end
  end
end
