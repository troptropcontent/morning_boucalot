require "rails_helper"

RSpec.describe IngestOffloadedPhotoFile do
  let(:owner) { FactoryBot.create(:user) }

  def call_with(fixture, as:)
    File.open(Rails.root.join("spec/fixtures/files/#{fixture}"), "rb") do |io|
      described_class.call(owner: owner, filename: as, io: io)
    end
  end

  context "with a JPEG" do
    it "creates an unpublished photo with the file attached" do
      expect { call_with("test_image.jpg", as: "DSCF0001.JPG") }.to change { owner.photos.count }.by(1)

      photo = owner.photos.last
      expect(photo.published).to be false
      expect(photo.file).to be_attached
    end

    it "sets file_size" do
      call_with("test_image.jpg", as: "DSCF0002.JPG")
      expect(owner.photos.last.file_size).to eq(Rails.root.join("spec/fixtures/files/test_image.jpg").size)
    end

    it "enqueues ProcessPhotoJob" do
      expect { call_with("test_image.jpg", as: "DSCF0003.JPG") }.to have_enqueued_job(ProcessPhotoJob)
    end
  end

  context "with a RAF only" do
    it "creates an unpublished photo with only raw_file attached" do
      expect { call_with("test_raw.raf", as: "DSCF0005.RAF") }.to change { owner.photos.count }.by(1)

      photo = owner.photos.last
      expect(photo.raw_file).to be_attached
      expect(photo.file).not_to be_attached
    end

    it "does not enqueue ProcessPhotoJob" do
      expect { call_with("test_raw.raf", as: "DSCF0006.RAF") }.not_to have_enqueued_job(ProcessPhotoJob)
    end
  end

  context "when the JPEG and RAF of the same shot arrive separately" do
    it "pairs them onto the same photo when the JPEG arrives first" do
      call_with("test_image.jpg", as: "DSCF0007.JPG")

      expect { call_with("test_raw.raf", as: "DSCF0007.RAF") }.not_to change { owner.photos.count }

      photo = owner.photos.last
      expect(photo.file).to be_attached
      expect(photo.raw_file).to be_attached
    end

    it "pairs them onto the same photo when the RAF arrives first" do
      call_with("test_raw.raf", as: "DSCF0008.RAF")

      expect { call_with("test_image.jpg", as: "DSCF0008.JPG") }.not_to change { owner.photos.count }

      photo = owner.photos.last
      expect(photo.file).to be_attached
      expect(photo.raw_file).to be_attached
    end

    it "does not pair files with different stems" do
      call_with("test_image.jpg", as: "DSCF0009.JPG")

      expect { call_with("test_raw.raf", as: "DSCF0010.RAF") }.to change { owner.photos.count }.by(1)
    end
  end

  context "with a duplicate upload (same checksum, e.g. a camera retry)" do
    it "fails without creating a second photo" do
      call_with("test_image.jpg", as: "DSCF0011.JPG")

      result = nil
      expect {
        result = call_with("test_image.jpg", as: "DSCF0011_RETRY.JPG")
      }.not_to change { owner.photos.count }

      expect(result.success?).to be false
      expect(result.errors).to eq([ "duplicate" ])
    end

    it "does not leave an orphaned blob" do
      call_with("test_image.jpg", as: "DSCF0013.JPG")
      blob_count_before = ActiveStorage::Blob.count

      call_with("test_image.jpg", as: "DSCF0013_RETRY.JPG")

      expect(ActiveStorage::Blob.count).to eq(blob_count_before)
    end
  end

  context "with an unrecognized extension" do
    it "fails without creating a photo" do
      result = nil
      expect { result = call_with("test_image.jpg", as: "DSCF0015.TXT") }.not_to change(Photo, :count)

      expect(result.success?).to be false
      expect(result.errors).to eq([ "unsupported file type" ])
    end
  end
end
