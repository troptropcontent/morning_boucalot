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

  it "serializes jobs for the same filename stem, so a RAF/JPEG pair or a re-scanned duplicate can't run concurrently" do
    job = described_class.new("/data/ftp_incoming/DSCF0001.JPG")
    expect(job.concurrency_key).to eq(job.class.name + "/DSCF0001")

    other_extension_job = described_class.new("/data/ftp_incoming/DSCF0001.RAF")
    expect(other_extension_job.concurrency_key).to eq(job.concurrency_key)
  end

  describe "#perform" do
    it "hands the file off to IngestOffloadedPhotoFile, creating an unpublished photo" do
      path = copy_fixture("test_image.jpg", as: "DSCF0001.JPG")

      expect { described_class.new.perform(path) }.to change { user.photos.count }.by(1)

      photo = user.photos.last
      expect(photo.published).to be false
      expect(photo.file).to be_attached
    end

    it "deletes the source file once ingestion has run" do
      path = copy_fixture("test_image.jpg", as: "DSCF0004.JPG")
      described_class.new.perform(path)
      expect(File.exist?(path)).to be false
    end

    it "deletes the source file even when ingestion fails (e.g. unrecognized extension)" do
      path = copy_fixture("test_image.jpg", as: "DSCF0015.TXT")

      expect { described_class.new.perform(path) }.not_to change(Photo, :count)
      expect(File.exist?(path)).to be false
    end

    context "when FTP_INGEST_USER_EMAIL is not configured" do
      it "does nothing and leaves the file in place" do
        ENV["FTP_INGEST_USER_EMAIL"] = nil
        path = copy_fixture("test_image.jpg", as: "DSCF0014.JPG")

        expect { described_class.new.perform(path) }.not_to change(Photo, :count)
        expect(File.exist?(path)).to be true
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
  end
end
