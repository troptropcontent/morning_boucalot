require "rails_helper"

RSpec.describe FindDefaultGalleryOwnerForUser do
  describe ".call" do
    it "returns the user themselves when they're a member" do
      member = FactoryBot.create(:user)

      result = FindDefaultGalleryOwnerForUser.call(user: member).data

      expect(result).to eq(member)
    end

    it "returns the app's member when the user is a guest" do
      member = FactoryBot.create(:user)
      guest = FactoryBot.create(:user, :guest)

      result = FindDefaultGalleryOwnerForUser.call(user: guest).data

      expect(result).to eq(member)
    end
  end
end
