require "rails_helper"
require "zip"

RSpec.describe DownloadPhotos do
  let(:owner) { FactoryBot.create(:user) }
  let!(:photos) { FactoryBot.create_list(:photo, 2, user: owner) }

  def zip_entries(data)
    entries = []
    Zip::InputStream.open(StringIO.new(data)) do |zip|
      while (entry = zip.get_next_entry)
        entries << entry.name
      end
    end
    entries
  end

  describe ".call" do
    it "returns a valid ZIP archive containing one entry per photo" do
      result = DownloadPhotos.call(owner: owner, photo_ids: photos.map(&:id))
      expect(result).to be_success
      expect(zip_entries(result.data).size).to eq(2)
    end

    it "names entries using the photo title" do
      photo = FactoryBot.create(:photo, user: owner, title: "Mountain View")
      result = DownloadPhotos.call(owner: owner, photo_ids: [ photo.id ])
      expect(zip_entries(result.data)).to eq([ "mountain_view.jpg" ])
    end

    it "deduplicates entries when photos share the same title" do
      photo1 = FactoryBot.create(:photo, user: owner, title: "Sunset")
      photo2 = FactoryBot.create(:photo, user: owner, title: "Sunset")
      result = DownloadPhotos.call(owner: owner, photo_ids: [ photo1.id, photo2.id ])
      expect(zip_entries(result.data)).to eq([ "sunset.jpg", "sunset_2.jpg" ])
    end

    it "scopes to the owner's photos and ignores foreign ids" do
      other_photo = FactoryBot.create(:photo)
      result = DownloadPhotos.call(owner: owner, photo_ids: [ other_photo.id ])
      expect(result).to be_failure
      expect(result.errors).to include("No matching photos found")
    end

    it "fails when photo_ids is empty" do
      result = DownloadPhotos.call(owner: owner, photo_ids: [])
      expect(result).to be_failure
      expect(result.errors).to include("No photos selected")
    end

    context "with variant: :large" do
      it "returns a valid ZIP archive" do
        photo = FactoryBot.create(:photo, user: owner)
        result = DownloadPhotos.call(owner: owner, photo_ids: [ photo.id ], variant: :large)
        expect(result).to be_success
        expect(zip_entries(result.data).size).to eq(1)
      end
    end

    it "ignores unknown variant values and falls back to original" do
      photo = FactoryBot.create(:photo, user: owner)
      result = DownloadPhotos.call(owner: owner, photo_ids: [ photo.id ], variant: :unknown)
      expect(result).to be_success
    end
  end
end
