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
