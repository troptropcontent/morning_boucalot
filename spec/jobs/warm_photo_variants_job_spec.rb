require "rails_helper"

RSpec.describe WarmPhotoVariantsJob do
  describe "#perform" do
    it "warms the photo's variants" do
      photo = FactoryBot.create(:photo)
      expect(WarmPhotoVariants).to receive(:call).with(photo: photo)

      described_class.new.perform(photo.id)
    end

    it "does nothing when the photo no longer exists" do
      expect(WarmPhotoVariants).not_to receive(:call)

      described_class.new.perform(-1)
    end

    it "retries on ENOSPC" do
      expect(described_class.rescue_handlers.map(&:first)).to include("Errno::ENOSPC")
    end
  end
end
