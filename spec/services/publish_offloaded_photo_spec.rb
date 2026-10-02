require "rails_helper"

RSpec.describe PublishOffloadedPhoto do
  describe ".call" do
    it "marks the photo as published" do
      photo = FactoryBot.create(:photo, published: false)
      PublishOffloadedPhoto.call(photo: photo)
      expect(photo.reload.published).to be true
    end

    it "returns a successful result" do
      photo = FactoryBot.create(:photo, published: false)
      result = PublishOffloadedPhoto.call(photo: photo)
      expect(result).to be_success
    end
  end
end
