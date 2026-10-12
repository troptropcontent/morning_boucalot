require "rails_helper"

RSpec.describe ArchivePhoto do
  describe ".call" do
    it "sets archived_at on the photo" do
      photo = FactoryBot.create(:photo)
      expect { ArchivePhoto.call(photo: photo) }.to change { photo.reload.archived_at }.from(nil)
    end

    it "returns a successful result" do
      photo = FactoryBot.create(:photo)
      result = ArchivePhoto.call(photo: photo)
      expect(result).to be_success
    end
  end
end
