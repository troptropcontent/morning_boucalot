require "rails_helper"

RSpec.describe OffloadIngestOwner do
  let(:user) { FactoryBot.create(:user) }

  around do |example|
    original_email = ENV["FTP_INGEST_USER_EMAIL"]
    example.run
    ENV["FTP_INGEST_USER_EMAIL"] = original_email
  end

  it "finds the user matching FTP_INGEST_USER_EMAIL" do
    ENV["FTP_INGEST_USER_EMAIL"] = user.email_address
    expect(described_class.find).to eq(user)
  end

  it "returns nil when FTP_INGEST_USER_EMAIL is not configured" do
    ENV["FTP_INGEST_USER_EMAIL"] = nil
    expect(described_class.find).to be_nil
  end

  it "returns nil when no user matches the configured email" do
    ENV["FTP_INGEST_USER_EMAIL"] = "nobody@example.com"
    expect(described_class.find).to be_nil
  end
end
