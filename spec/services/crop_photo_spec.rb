require "rails_helper"

RSpec.describe CropPhoto do
  let(:photo) { FactoryBot.create(:photo) }

  def crop(box)
    described_class.call(photo: photo, box: box)
  end

  describe ".call" do
    it "stores the crop as fractions" do
      result = crop(x: "0.1", y: "0.2", w: "0.5", h: "0.25")

      expect(result).to be_success
      expect(photo.reload.crop_box).to eq([ 0.1, 0.2, 0.5, 0.25 ])
    end

    it "accepts string keys, as params arrive" do
      crop("x" => "0", "y" => "0", "w" => "0.5", "h" => "0.5")

      expect(photo.reload.crop_box).to eq([ 0, 0, 0.5, 0.5 ])
    end

    it "clamps float noise from the browser back inside the image" do
      result = crop(x: "0.5", y: "-0.0000001", w: "0.5000004", h: "1.0000002")

      expect(result).to be_success
      expect(photo.reload.crop_box).to eq([ 0.5, 0, 0.5, 1 ])
    end

    it "clears the crop when the box covers the whole image" do
      photo.update!(crop_x: 0, crop_y: 0, crop_w: 0.5, crop_h: 0.5)

      crop(x: "0", y: "0", w: "1", h: "1")

      expect(photo.reload.crop_box).to be_nil
      expect(photo.crop_x).to be_nil
    end

    it "stores the straightening angle" do
      result = described_class.call(photo: photo, box: { x: "0", y: "0", w: "0.5", h: "0.5" }, angle: "-3.25")

      expect(result).to be_success
      expect(photo.reload.straighten_angle).to eq(-3.25)
    end

    it "clamps the angle to the allowed range and rounds it to the column's scale" do
      described_class.call(photo: photo, box: { x: "0", y: "0", w: "1", h: "1" }, angle: "50.123")

      expect(photo.reload.straighten_angle).to eq(45)

      described_class.call(photo: photo, box: { x: "0", y: "0", w: "1", h: "1" }, angle: "1.23456")

      expect(photo.reload.straighten_angle).to eq(1.23)
    end

    it "straightens without cropping when the box covers the whole straightened image" do
      described_class.call(photo: photo, box: { x: "0", y: "0", w: "1", h: "1" }, angle: "2")

      expect(photo.reload.crop_box).to be_nil
      expect(photo.straighten_angle).to eq(2)
      expect(photo.edits).to be_edited
    end

    it "keeps the current angle when none is given" do
      photo.update!(straighten_angle: 4)

      crop(x: "0", y: "0", w: "0.5", h: "0.5")

      expect(photo.reload.straighten_angle).to eq(4)
    end

    [ "abc", "Infinity", "" ].each do |angle|
      it "fails on an angle of #{angle.inspect} without changing the photo" do
        result = described_class.call(photo: photo, box: { x: "0", y: "0", w: "0.5", h: "0.5" }, angle: angle)

        expect(result).to be_failure
        expect(result.errors).to eq([ "Straightening angle is invalid" ])
        expect(photo.reload.crop_box).to be_nil
      end
    end

    it "keeps the rotation" do
      photo.update!(rotation: 90)

      crop(x: "0", y: "0", w: "0.5", h: "0.5")

      expect(photo.reload.rotation).to eq(90)
    end

    it "analyzes the image first if it hasn't been yet, so the crop can be measured" do
      expect(photo.file.blob).not_to be_analyzed

      crop(x: "0", y: "0", w: "0.5", h: "0.5")

      expect(photo.file.blob.reload).to be_analyzed
      expect(photo.reload.edits.dimensions).to eq([ 2576, 3864 ])
    end

    it "enqueues a warm-up of the new variants" do
      expect { crop(x: "0", y: "0", w: "0.5", h: "0.5") }.to have_enqueued_job(WarmPhotoVariantsJob).with(photo.id)
    end

    it "returns the photo" do
      expect(crop(x: "0", y: "0", w: "0.5", h: "0.5").data).to eq(photo)
    end

    [
      [ "a missing value", { x: "0", y: "0", w: "0.5" } ],
      [ "a non-numeric value", { x: "0", y: "0", w: "abc", h: "0.5" } ],
      [ "an infinite value", { x: "0", y: "0", w: "Infinity", h: "0.5" } ],
      [ "an empty box", { x: "0", y: "0", w: "0", h: "0.5" } ],
      [ "a box starting past the edge", { x: "1", y: "0", w: "0.5", h: "0.5" } ]
    ].each do |description, box|
      it "fails on #{description} without changing the photo" do
        result = crop(box)

        expect(result).to be_failure
        expect(result.errors).to eq([ "Crop is missing or invalid" ])
        expect(photo.reload.crop_box).to be_nil
      end
    end

    it "fails when no box is given" do
      expect(described_class.call(photo: photo, box: nil)).to be_failure
    end

    it "fails for a photo without an image file" do
      photo.file.purge

      result = described_class.call(photo: photo.reload, box: { x: "0", y: "0", w: "0.5", h: "0.5" })

      expect(result).to be_failure
      expect(result.errors).to eq([ "Only photos with an image file can be cropped" ])
    end

    it "fails with the validation errors when the photo can't be saved" do
      allow(photo).to receive(:update) do
        photo.errors.add(:base, "Nope")
        false
      end

      result = crop(x: "0", y: "0", w: "0.5", h: "0.5")

      expect(result).to be_failure
      expect(result.errors).to eq([ "Nope" ])
    end
  end
end
