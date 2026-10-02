require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe IngestOffloadedPhotoJob do
  let(:user) { FactoryBot.create(:user) }
  let(:incoming_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = ENV["FTP_INCOMING_DIR"]
    original_email = ENV["FTP_INGEST_USER_EMAIL"]
    ENV["FTP_INCOMING_DIR"] = incoming_dir
    ENV["FTP_INGEST_USER_EMAIL"] = user.email_address

    example.run

    ENV["FTP_INCOMING_DIR"] = original_dir
    ENV["FTP_INGEST_USER_EMAIL"] = original_email
    FileUtils.remove_entry(incoming_dir) if File.directory?(incoming_dir)
  end

  def copy_fixture(name, as:)
    destination = File.join(incoming_dir, as)
    FileUtils.cp(Rails.root.join("spec/fixtures/files/#{name}"), destination)
    destination
  end

  describe "#perform" do
    context "with a JPEG" do
      it "creates an unpublished photo with the file attached" do
        path = copy_fixture("test_image.jpg", as: "DSCF0001.JPG")

        expect { described_class.new.perform(path) }.to change { user.photos.count }.by(1)

        photo = user.photos.last
        expect(photo.published).to be false
        expect(photo.file).to be_attached
      end

      it "sets file_size" do
        path = copy_fixture("test_image.jpg", as: "DSCF0002.JPG")
        described_class.new.perform(path)
        expect(user.photos.last.file_size).to eq(Rails.root.join("spec/fixtures/files/test_image.jpg").size)
      end

      it "enqueues ProcessPhotoJob" do
        path = copy_fixture("test_image.jpg", as: "DSCF0003.JPG")
        expect { described_class.new.perform(path) }.to have_enqueued_job(ProcessPhotoJob)
      end

      it "deletes the source file" do
        path = copy_fixture("test_image.jpg", as: "DSCF0004.JPG")
        described_class.new.perform(path)
        expect(File.exist?(path)).to be false
      end
    end

    context "with a RAF only" do
      it "creates an unpublished photo with only raw_file attached" do
        path = copy_fixture("test_raw.raf", as: "DSCF0005.RAF")

        expect { described_class.new.perform(path) }.to change { user.photos.count }.by(1)

        photo = user.photos.last
        expect(photo.raw_file).to be_attached
        expect(photo.file).not_to be_attached
      end

      it "does not enqueue ProcessPhotoJob" do
        path = copy_fixture("test_raw.raf", as: "DSCF0006.RAF")
        expect { described_class.new.perform(path) }.not_to have_enqueued_job(ProcessPhotoJob)
      end
    end

    context "when the JPEG and RAF of the same shot arrive separately" do
      it "pairs them onto the same photo when the JPEG arrives first" do
        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0007.JPG"))

        expect {
          described_class.new.perform(copy_fixture("test_raw.raf", as: "DSCF0007.RAF"))
        }.not_to change { user.photos.count }

        photo = user.photos.last
        expect(photo.file).to be_attached
        expect(photo.raw_file).to be_attached
      end

      it "pairs them onto the same photo when the RAF arrives first" do
        described_class.new.perform(copy_fixture("test_raw.raf", as: "DSCF0008.RAF"))

        expect {
          described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0008.JPG"))
        }.not_to change { user.photos.count }

        photo = user.photos.last
        expect(photo.file).to be_attached
        expect(photo.raw_file).to be_attached
      end

      it "does not pair files with different stems" do
        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0009.JPG"))

        expect {
          described_class.new.perform(copy_fixture("test_raw.raf", as: "DSCF0010.RAF"))
        }.to change { user.photos.count }.by(1)
      end
    end

    context "with a duplicate upload (same checksum, e.g. a camera retry)" do
      it "does not create a second photo" do
        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0011.JPG"))

        expect {
          described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0011_RETRY.JPG"))
        }.not_to change { user.photos.count }
      end

      it "deletes the retried source file" do
        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0012.JPG"))
        retry_path = copy_fixture("test_image.jpg", as: "DSCF0012_RETRY.JPG")

        described_class.new.perform(retry_path)

        expect(File.exist?(retry_path)).to be false
      end

      it "does not leave an orphaned blob" do
        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0013.JPG"))
        blob_count_before = ActiveStorage::Blob.count

        described_class.new.perform(copy_fixture("test_image.jpg", as: "DSCF0013_RETRY.JPG"))

        expect(ActiveStorage::Blob.count).to eq(blob_count_before)
      end
    end

    context "when FTP_INGEST_USER_EMAIL is not configured" do
      it "does nothing" do
        ENV["FTP_INGEST_USER_EMAIL"] = nil
        path = copy_fixture("test_image.jpg", as: "DSCF0014.JPG")

        expect { described_class.new.perform(path) }.not_to change(Photo, :count)
      end
    end

    context "when the file is outside the configured incoming dir" do
      it "does nothing, guarding against a path-traversal file_path" do
        outside_dir = Dir.mktmpdir
        outside_path = File.join(outside_dir, "DSCF9999.JPG")
        FileUtils.cp(Rails.root.join("spec/fixtures/files/test_image.jpg"), outside_path)

        expect { described_class.new.perform(outside_path) }.not_to change(Photo, :count)
        expect(File.exist?(outside_path)).to be true
      ensure
        FileUtils.remove_entry(outside_dir) if outside_dir && File.directory?(outside_dir)
      end
    end

    context "when the file does not exist" do
      it "does nothing" do
        expect { described_class.new.perform(File.join(incoming_dir, "missing.jpg")) }.not_to raise_error
      end
    end

    context "with an unrecognized extension" do
      it "does nothing and leaves the file in place" do
        path = copy_fixture("test_image.jpg", as: "DSCF0015.TXT")

        expect { described_class.new.perform(path) }.not_to change(Photo, :count)
        expect(File.exist?(path)).to be true
      end
    end
  end
end
