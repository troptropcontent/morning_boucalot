require "rails_helper"

RSpec.describe "RafUploads", type: :request do
  let(:user) { FactoryBot.create(:user) }
  let(:token) { "secret-upload-token" }
  let(:bucket) { instance_double(RafBucket, exists?: false, presigned_put_url: "https://s3/put") }

  around do |example|
    original_token = ENV["OFFLOAD_UPLOAD_TOKEN"]
    original_email = ENV["FTP_INGEST_USER_EMAIL"]
    ENV["OFFLOAD_UPLOAD_TOKEN"] = token
    ENV["FTP_INGEST_USER_EMAIL"] = user.email_address
    example.run
    ENV["OFFLOAD_UPLOAD_TOKEN"] = original_token
    ENV["FTP_INGEST_USER_EMAIL"] = original_email
  end

  before { allow(RafBucket).to receive(:new).and_return(bucket) }

  def post_presign(params = { filename: "DSCF1234.RAF", size: 50 }, token: self.token)
    post "/raf_uploads/presign", params: params, headers: { "Authorization" => "Bearer #{token}" }
  end

  it "returns a presigned URL" do
    post_presign

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("already_uploaded" => false, "url" => "https://s3/put")
  end

  it "says so when the RAF is already uploaded" do
    allow(bucket).to receive(:exists?).and_return(true)

    post_presign

    expect(response.parsed_body).to eq("already_uploaded" => true)
  end

  it "rejects a non-RAF filename" do
    post_presign({ filename: "x.jpg", size: 5 })

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects a wrong token" do
    post_presign(token: "nope")

    expect(response).to have_http_status(:unauthorized)
  end

  it "is unavailable without an ingest owner" do
    ENV["FTP_INGEST_USER_EMAIL"] = nil

    post_presign

    expect(response).to have_http_status(:service_unavailable)
  end
end
