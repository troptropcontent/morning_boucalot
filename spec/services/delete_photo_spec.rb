require "rails_helper"

RSpec.describe DeletePhoto do
  describe ".call" do
    it "destroys the photo" do
      photo = FactoryBot.create(:photo)
      expect {
        DeletePhoto.call(photo: photo)
      }.to change(Photo, :count).by(-1)
    end

    it "returns a successful result" do
      photo = FactoryBot.create(:photo)
      result = DeletePhoto.call(photo: photo)
      expect(result).to be_success
    end
  end
end
