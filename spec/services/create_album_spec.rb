require "rails_helper"

RSpec.describe CreateAlbum do
  let(:user) { FactoryBot.create(:user) }

  describe ".call" do
    it "creates an album for the user" do
      expect {
        CreateAlbum.call(user: user, params: { title: "Summer 2024" })
      }.to change { user.albums.count }.by(1)
    end

    it "returns the created album" do
      result = CreateAlbum.call(user: user, params: { title: "Summer 2024", description: "Beach trip" })
      expect(result).to be_success
      expect(result.data.title).to eq("Summer 2024")
      expect(result.data.description).to eq("Beach trip")
    end

    it "fails without a title" do
      result = CreateAlbum.call(user: user, params: { title: "" })
      expect(result).to be_failure
      expect(result.errors).to include("Title can't be blank")
    end
  end
end
