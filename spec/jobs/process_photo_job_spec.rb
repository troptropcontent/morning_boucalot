require "rails_helper"

RSpec.describe ProcessPhotoJob do
  let(:photo) { FactoryBot.create(:photo, status: :pending, taken_at: nil, camera_model: nil) }

  describe "#perform" do
    context "when the photo exists and file is attached" do
      it "sets status to ready" do
        described_class.new.perform(photo.id)
        expect(photo.reload.status).to eq("ready")
      end

      it "calls ExtractExifData for a JPEG" do
        expect(ExtractExifData).to receive(:call).and_return({})
        described_class.new.perform(photo.id)
      end

      it "pre-warms image variants" do
        described_class.new.perform(photo.id)
        expect(photo.file.variant(:thumbnail).processed).to be_present
        expect(photo.file.variant(:medium).processed).to be_present
      end
    end

    context "when the photo does not exist" do
      it "does nothing" do
        expect { described_class.new.perform(-1) }.not_to raise_error
      end
    end

    context "when the photo has no attached file" do
      it "does nothing" do
        photo.file.purge
        expect { described_class.new.perform(photo.id) }.not_to raise_error
      end
    end

    context "when EXIF extraction raises an error" do
      before do
        allow(ExtractExifData).to receive(:call).and_raise(StandardError, "corrupt file")
      end

      it "marks the photo as failed" do
        expect { described_class.new.perform(photo.id) }.to raise_error(StandardError)
        expect(photo.reload.status).to eq("failed")
      end
    end
  end
end
