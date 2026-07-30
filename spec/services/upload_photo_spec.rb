require "rails_helper"

RSpec.describe UploadPhoto do
  let(:user) { FactoryBot.create(:user) }
  let(:file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/test_image.jpg"),
      "image/jpeg"
    )
  end

  describe ".call" do
    context "with a valid file" do
      it "returns a successful result" do
        result = UploadPhoto.call(user: user, params: { file: file })
        expect(result).to be_success
      end

      it "creates a photo attached to the user" do
        expect {
          UploadPhoto.call(user: user, params: { file: file })
        }.to change { user.photos.count }.by(1)
      end

      it "attaches the file to the photo" do
        result = UploadPhoto.call(user: user, params: { file: file })
        expect(result.data.file).to be_attached
      end

      it "sets the file size" do
        result = UploadPhoto.call(user: user, params: { file: file })
        expect(result.data.file_size).to eq(file.size)
      end

      it "sets optional title and description" do
        result = UploadPhoto.call(user: user, params: { file: file, title: "Sunset", description: "Beautiful" })
        expect(result.data.title).to eq("Sunset")
        expect(result.data.description).to eq("Beautiful")
      end

      it "assigns tags from tag_list" do
        result = UploadPhoto.call(user: user, params: { file: file, tag_list: "landscape, travel" })
        expect(result.data.tags.map(&:name)).to contain_exactly("landscape", "travel")
      end

      it "creates photos without tags when tag_list is blank" do
        result = UploadPhoto.call(user: user, params: { file: file, tag_list: "" })
        expect(result.data.tags).to be_empty
      end

      it "saves the photo with pending status" do
        result = UploadPhoto.call(user: user, params: { file: file })
        expect(result.data.status).to eq("pending")
      end

      it "enqueues a ProcessPhotoJob" do
        expect {
          UploadPhoto.call(user: user, params: { file: file })
        }.to have_enqueued_job(ProcessPhotoJob)
      end

      it "does not extract EXIF during the upload" do
        expect(ExtractExifData).not_to receive(:call)
        UploadPhoto.call(user: user, params: { file: file })
      end
    end

    context "with a duplicate file (same checksum)" do
      before { UploadPhoto.call(user: user, params: { file: file }) }

      it "returns a failure result" do
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        result = UploadPhoto.call(user: user, params: { file: duplicate_file })
        expect(result).to be_failure
      end

      it "returns a duplicate error" do
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        result = UploadPhoto.call(user: user, params: { file: duplicate_file })
        expect(result.errors).to eq([ "duplicate" ])
      end

      it "does not create a new photo" do
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        expect {
          UploadPhoto.call(user: user, params: { file: duplicate_file })
        }.not_to change { user.photos.count }
      end

      it "does not leave an orphaned blob" do
        blob_count_before = ActiveStorage::Blob.count
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        UploadPhoto.call(user: user, params: { file: duplicate_file })
        expect(ActiveStorage::Blob.count).to eq(blob_count_before)
      end

      it "allows the same file for a different user" do
        other_user = FactoryBot.create(:user)
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        result = UploadPhoto.call(user: other_user, params: { file: duplicate_file })
        expect(result).to be_success
      end
    end

    context "without a file" do
      it "returns a failure result" do
        result = UploadPhoto.call(user: user, params: {})
        expect(result).to be_failure
      end

      it "includes an error message" do
        result = UploadPhoto.call(user: user, params: {})
        expect(result.errors).to include("File is required")
      end
    end
  end
end
