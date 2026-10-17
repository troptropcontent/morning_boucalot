require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "OffloadUploads", type: :request do
  let(:user) { FactoryBot.create(:user) }
  let(:token) { "secret-upload-token" }
  let(:tmp_dir) { Dir.mktmpdir }

  around do |example|
    original_token = ENV["OFFLOAD_UPLOAD_TOKEN"]
    original_email = ENV["FTP_INGEST_USER_EMAIL"]
    ENV["OFFLOAD_UPLOAD_TOKEN"] = token
    ENV["FTP_INGEST_USER_EMAIL"] = user.email_address

    example.run

    ENV["OFFLOAD_UPLOAD_TOKEN"] = original_token
    ENV["FTP_INGEST_USER_EMAIL"] = original_email
    FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir)
  end

  def upload_fixture(fixture, as:, content_type: "image/jpeg")
    destination = File.join(tmp_dir, as)
    FileUtils.cp(Rails.root.join("spec/fixtures/files/#{fixture}"), destination)
    Rack::Test::UploadedFile.new(destination, content_type)
  end

  def post_upload(file, token: self.token)
    headers = token ? { "Authorization" => "Bearer #{token}" } : {}
    post offload_uploads_path, params: { file: file }, headers: headers
  end

  describe "POST /offload_uploads" do
    context "without a token" do
      it "returns 401 and creates nothing" do
        file = upload_fixture("test_image.jpg", as: "DSCF0001.JPG")
        expect { post_upload(file, token: nil) }.not_to change(Photo, :count)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with the wrong token" do
      it "returns 401" do
        file = upload_fixture("test_image.jpg", as: "DSCF0002.JPG")
        post_upload(file, token: "wrong-token")
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when OFFLOAD_UPLOAD_TOKEN is not configured" do
      it "returns 503 even with a token supplied" do
        ENV["OFFLOAD_UPLOAD_TOKEN"] = nil
        file = upload_fixture("test_image.jpg", as: "DSCF0003.JPG")
        post_upload(file)
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context "when FTP_INGEST_USER_EMAIL has no matching user" do
      it "returns 503" do
        ENV["FTP_INGEST_USER_EMAIL"] = "nobody@example.com"
        file = upload_fixture("test_image.jpg", as: "DSCF0004.JPG")
        post_upload(file)
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context "with a valid token" do
      it "creates an unpublished photo and returns 201" do
        file = upload_fixture("test_image.jpg", as: "DSCF0005.JPG")

        expect { post_upload(file) }.to change { user.photos.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["status"]).to eq("created")
        expect(response.parsed_body["id"]).to eq(user.photos.last.id)
        expect(user.photos.last.published).to be false
      end

      it "pairs a RAF with an existing JPEG of the same stem" do
        post_upload(upload_fixture("test_image.jpg", as: "DSCF0006.JPG"))

        expect {
          post_upload(upload_fixture("test_raw.raf", as: "DSCF0006.RAF", content_type: "application/octet-stream"))
        }.not_to change { user.photos.count }

        photo = user.photos.last
        expect(photo.file).to be_attached
        expect(photo.raw_file).to be_attached
      end

      it "returns 200 with duplicate status for a repeat checksum" do
        post_upload(upload_fixture("test_image.jpg", as: "DSCF0007.JPG"))

        expect {
          post_upload(upload_fixture("test_image.jpg", as: "DSCF0007_RETRY.JPG"))
        }.not_to change(Photo, :count)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("duplicate")
      end

      it "returns 422 for an unsupported file type" do
        file = upload_fixture("test_image.jpg", as: "DSCF0008.TXT", content_type: "text/plain")
        post_upload(file)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 400 when no file is given" do
        post offload_uploads_path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
