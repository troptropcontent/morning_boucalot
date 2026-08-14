require "rails_helper"

RSpec.describe GalleryPolicy do
  let(:member) { FactoryBot.create(:user) }

  describe "#owner?" do
    it "is true for the member on their own gallery" do
      expect(described_class.new(user: member, owner: member).owner?).to be true
    end

    it "is false for a guest, even on the gallery they're routed to" do
      guest = FactoryBot.create(:user, :guest)

      expect(described_class.new(user: guest, owner: member).owner?).to be false
    end

    it "is false for a different member" do
      other_member = FactoryBot.create(:user)

      expect(described_class.new(user: other_member, owner: member).owner?).to be false
    end

    it "is false when nobody is signed in" do
      expect(described_class.new(user: nil, owner: member).owner?).to be false
    end
  end

  describe "#viewer?" do
    it "is true for the member on their own gallery" do
      expect(described_class.new(user: member, owner: member).viewer?).to be true
    end

    it "is true for a guest on the gallery they're routed to" do
      member # ensure the member exists before the guest is routed
      guest = FactoryBot.create(:user, :guest)

      expect(described_class.new(user: guest, owner: member).viewer?).to be true
    end

    it "is false for a guest on a gallery other than the one they're routed to" do
      member # the guest is routed to this member, created first
      other_member = FactoryBot.create(:user)
      guest = FactoryBot.create(:user, :guest)

      expect(described_class.new(user: guest, owner: other_member).viewer?).to be false
    end

    it "is false when nobody is signed in" do
      expect(described_class.new(user: nil, owner: member).viewer?).to be false
    end
  end
end
