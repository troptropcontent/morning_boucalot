require "rails_helper"

RSpec.describe RotatePhoto do
  let(:photo) { FactoryBot.create(:photo) }

  describe ".call" do
    it "rotates clockwise by a quarter turn" do
      result = described_class.call(photo: photo, direction: "clockwise")

      expect(result).to be_success
      expect(photo.reload.rotation).to eq(90)
    end

    it "rotates counterclockwise by a quarter turn" do
      photo.update!(rotation: 180)

      described_class.call(photo: photo, direction: "counterclockwise")

      expect(photo.reload.rotation).to eq(90)
    end

    it "wraps from 270 to 0 clockwise" do
      photo.update!(rotation: 270)

      described_class.call(photo: photo, direction: "clockwise")

      expect(photo.reload.rotation).to eq(0)
    end

    it "wraps from 0 to 270 counterclockwise" do
      described_class.call(photo: photo, direction: :counterclockwise)

      expect(photo.reload.rotation).to eq(270)
    end

    it "builds on the stored rotation rather than a stale in-memory one" do
      stale = Photo.find(photo.id)
      described_class.call(photo: photo, direction: "clockwise")

      described_class.call(photo: stale, direction: "clockwise")

      expect(photo.reload.rotation).to eq(180)
    end

    it "returns the photo" do
      expect(described_class.call(photo: photo, direction: "clockwise").data).to eq(photo)
    end

    it "enqueues a warm-up of the new variants" do
      expect { described_class.call(photo: photo, direction: "clockwise") }
        .to have_enqueued_job(WarmPhotoVariantsJob).with(photo.id)
    end

    it "fails on an unknown direction without changing the photo" do
      result = described_class.call(photo: photo, direction: "sideways")

      expect(result).to be_failure
      expect(result.errors).to eq([ "Unknown rotation direction" ])
      expect(photo.reload.rotation).to eq(0)
    end

    it "fails when no direction is given" do
      expect(described_class.call(photo: photo, direction: nil)).to be_failure
    end

    it "fails for a raw-only photo, which has no image to rotate" do
      photo.file.purge

      result = nil
      expect { result = described_class.call(photo: photo.reload, direction: "clockwise") }
        .not_to have_enqueued_job(WarmPhotoVariantsJob)

      expect(result).to be_failure
      expect(photo.reload.rotation).to eq(0)
    end

    it "fails with the validation errors when the photo can't be saved" do
      allow(photo).to receive(:update) do
        photo.errors.add(:base, "Nope")
        false
      end

      result = described_class.call(photo: photo, direction: "clockwise")

      expect(result).to be_failure
      expect(result.errors).to eq([ "Nope" ])
    end
  end
end
