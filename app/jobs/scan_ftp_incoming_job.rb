# Runs on a schedule (see config/recurring.yml) instead of being triggered
# per upload — there's no webhook from the FTP server, so the app checks
# the incoming folder itself.
class ScanFtpIncomingJob < ApplicationJob
  queue_as :default

  # vsftpd writes bytes straight into the final filename as they arrive,
  # with no temp-file/rename step — so a file that's still mid-transfer
  # looks identical to a finished one except that its mtime keeps moving.
  # Only touching files whose mtime is already a bit stale avoids ingesting
  # a half-written upload.
  MIN_FILE_AGE = 10.seconds

  def perform
    incoming_dir = ENV["FTP_INCOMING_DIR"]
    return if incoming_dir.blank? || !File.directory?(incoming_dir)

    Dir.children(incoming_dir).each do |name|
      path = File.join(incoming_dir, name)
      next unless File.file?(path)
      next if File.mtime(path) > MIN_FILE_AGE.ago

      IngestOffloadedPhotoJob.perform_later(path)
    end
  end
end
