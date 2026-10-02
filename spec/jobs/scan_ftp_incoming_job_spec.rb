require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe ScanFtpIncomingJob do
  let(:incoming_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = ENV["FTP_INCOMING_DIR"]
    ENV["FTP_INCOMING_DIR"] = incoming_dir

    example.run

    ENV["FTP_INCOMING_DIR"] = original_dir
    FileUtils.remove_entry(incoming_dir) if File.directory?(incoming_dir)
  end

  def touch_file(name, mtime:)
    path = File.join(incoming_dir, name)
    FileUtils.touch(path, mtime: mtime.to_time)
    path
  end

  describe "#perform" do
    it "enqueues ingestion for a file that hasn't been touched recently" do
      path = touch_file("DSCF0001.JPG", mtime: 1.minute.ago)

      expect { described_class.new.perform }.to have_enqueued_job(IngestOffloadedPhotoJob).with(path)
    end

    it "does not enqueue ingestion for a file that was just modified (still mid-transfer)" do
      touch_file("DSCF0002.JPG", mtime: Time.current)

      expect { described_class.new.perform }.not_to have_enqueued_job(IngestOffloadedPhotoJob)
    end

    it "ignores subdirectories" do
      FileUtils.mkdir(File.join(incoming_dir, "a_directory"))

      expect { described_class.new.perform }.not_to have_enqueued_job(IngestOffloadedPhotoJob)
    end

    it "does nothing when FTP_INCOMING_DIR isn't configured" do
      ENV["FTP_INCOMING_DIR"] = nil

      expect { described_class.new.perform }.not_to raise_error
    end

    it "does nothing when the configured directory doesn't exist" do
      ENV["FTP_INCOMING_DIR"] = File.join(incoming_dir, "missing")

      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
