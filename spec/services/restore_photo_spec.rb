require "rails_helper"

RSpec.describe RestorePhoto do
  describe ".call" do
    it "clears archived_at on the photo" do
      photo = FactoryBot.create(:photo, :archived)
      expect { RestorePhoto.call(photo: photo) }.to change { photo.reload.archived_at }.to(nil)
    end

    it "returns a successful result" do
      photo = FactoryBot.create(:photo, :archived)
      result = RestorePhoto.call(photo: photo)
      expect(result).to be_success
    end
  end
end
