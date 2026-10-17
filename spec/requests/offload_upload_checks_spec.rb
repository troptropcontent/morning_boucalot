require "rails_helper"

RSpec.describe "OffloadUploadChecks", type: :request do
  let(:user) { FactoryBot.create(:user) }
  let(:token) { "secret-upload-token" }

  around do |example|
    original_token = ENV["OFFLOAD_UPLOAD_TOKEN"]
    original_email = ENV["FTP_INGEST_USER_EMAIL"]
    ENV["OFFLOAD_UPLOAD_TOKEN"] = token
    ENV["FTP_INGEST_USER_EMAIL"] = user.email_address

    example.run

    ENV["OFFLOAD_UPLOAD_TOKEN"] = original_token
    ENV["FTP_INGEST_USER_EMAIL"] = original_email
  end

  def post_check(checksums, token: self.token)
    headers = token ? { "Authorization" => "Bearer #{token}" } : {}
    post offload_upload_checks_path, params: { checksums: checksums }, headers: headers, as: :json
  end

  describe "POST /offload_uploads/check" do
    it "returns 401 without a token" do
      post_check([ "abc" ], token: nil)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with the wrong token" do
      post_check([ "abc" ], token: "wrong")
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 503 when the token is not configured" do
      ENV["OFFLOAD_UPLOAD_TOKEN"] = nil
      post_check([ "abc" ])
      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns 503 when there is no ingest owner" do
      ENV["FTP_INGEST_USER_EMAIL"] = "nobody@example.com"
      post_check([ "abc" ])
      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns only the checksums the server already has" do
      photo = FactoryBot.create(:photo, user: user)
      known = photo.file.blob.checksum

      post_check([ known, "never-seen" ])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("known" => [ known ])
    end

    it "returns 400 when checksums is missing" do
      post offload_upload_checks_path, headers: { "Authorization" => "Bearer #{token}" }, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when checksums contains non-strings" do
      post_check([ 1, { "a" => 1 } ])
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when too many checksums are sent" do
      post_check(Array.new(OffloadUploadChecksController::MAX_CHECKSUMS + 1) { |i| "c#{i}" })
      expect(response).to have_http_status(:bad_request)
    end
  end
end
