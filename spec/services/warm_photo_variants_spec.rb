require "rails_helper"

RSpec.describe WarmPhotoVariants do
  let(:photo) { FactoryBot.create(:photo, rotation: 90) }

  def processed?(photo, name)
    photo.file.blob.variant_records.exists?(variation_digest: photo.image_variant(name).variation.digest)
  end

  describe ".call" do
    it "processes the thumbnail, medium and large variants for the photo's current edits" do
      result = described_class.call(photo: photo)

      expect(result).to be_success
      expect(described_class::VARIANTS).to all(satisfy { |name| processed?(photo, name) })
    end

    it "does nothing for a photo without an image file" do
      photo.file.purge

      expect(described_class.call(photo: photo.reload)).to be_success
    end
  end
end
