# Single owner for all offloaded-photo ingestion -- both the FTP polling
# path and the HTTPS upload endpoint attribute incoming shots to this one
# account. Kept under the FTP_INGEST_USER_EMAIL name (rather than renaming to
# something protocol-agnostic) because it's already configured as a Kamal
# secret in production; renaming it would need a VPS-side env var change for
# no functional benefit.
module OffloadIngestOwner
  def self.find
    email = ENV["FTP_INGEST_USER_EMAIL"]
    return nil if email.blank?

    User.find_by(email_address: email)
  end
end
