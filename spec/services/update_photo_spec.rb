require "rails_helper"

RSpec.describe UpdatePhoto do
  let(:photo) { FactoryBot.create(:photo) }

  describe ".call" do
    it "updates title and description" do
      result = UpdatePhoto.call(photo: photo, params: { title: "New title", description: "New desc" })
      expect(result).to be_success
      expect(result.data.title).to eq("New title")
      expect(result.data.description).to eq("New desc")
    end

    it "returns the updated photo" do
      result = UpdatePhoto.call(photo: photo, params: { title: "Updated" })
      expect(result.data).to eq(photo)
    end

    it "updates tags when tag_list is provided" do
      result = UpdatePhoto.call(photo: photo, params: { title: "x", tag_list: "landscape, travel" })
      expect(result.data.tags.map(&:name)).to contain_exactly("landscape", "travel")
    end

    it "replaces existing tags" do
      SyncPhotoTags.call(photo: photo, tag_list: "old")
      result = UpdatePhoto.call(photo: photo, params: { title: "x", tag_list: "new" })
      expect(result.data.tags.map(&:name)).to eq([ "new" ])
    end

    it "does not touch tags when tag_list key is absent" do
      SyncPhotoTags.call(photo: photo, tag_list: "landscape")
      result = UpdatePhoto.call(photo: photo, params: { title: "x" })
      expect(result.data.tags.map(&:name)).to eq([ "landscape" ])
    end
  end
end
