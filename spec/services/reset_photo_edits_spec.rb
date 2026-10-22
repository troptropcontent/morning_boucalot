require "rails_helper"

RSpec.describe ResetPhotoEdits do
  let(:photo) { FactoryBot.create(:photo, rotation: 90, crop_x: 0, crop_y: 0, crop_w: 0.5, crop_h: 0.5) }

  describe ".call" do
    it "returns the photo to its original, unedited state" do
      result = described_class.call(photo: photo)

      expect(result).to be_success
      photo.reload
      expect(photo.rotation).to eq(0)
      expect(photo.crop_box).to be_nil
      expect(photo.edits).not_to be_edited
    end

    it "enqueues a warm-up of the unedited variants" do
      expect { described_class.call(photo: photo) }.to have_enqueued_job(WarmPhotoVariantsJob).with(photo.id)
    end

    it "fails with the validation errors when the photo can't be saved" do
      allow(photo).to receive(:update) do
        photo.errors.add(:base, "Nope")
        false
      end

      result = described_class.call(photo: photo)

      expect(result).to be_failure
      expect(result.errors).to eq([ "Nope" ])
    end
  end
end
