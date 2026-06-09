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
  end
end
