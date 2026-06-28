require "rails_helper"

RSpec.describe "Photos", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /:user_id/photos" do
    context "when not authenticated" do
      it "returns 200 for public access" do
        get user_photos_path(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "returns 200" do
        get user_photos_path(user)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /:user_id/photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    it "returns 200 without authentication" do
      get user_photo_path(user, photo)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a photo belonging to a different user" do
      other_photo = FactoryBot.create(:photo)
      get user_photo_path(user, other_photo)
      expect(response).to have_http_status(:not_found)
    end

    context "with adjacent photos" do
      let!(:older_photo)  { FactoryBot.create(:photo, user: user, taken_at: 2.days.ago) }
      let!(:middle_photo) { FactoryBot.create(:photo, user: user, taken_at: 1.day.ago) }
      let!(:newer_photo)  { FactoryBot.create(:photo, user: user, taken_at: Time.current) }

      it "shows both arrows for a middle photo" do
        get user_photo_path(user, middle_photo)
        expect(response.body).to include(user_photo_path(user, newer_photo))
        expect(response.body).to include(user_photo_path(user, older_photo))
      end

      it "shows no prev arrow for the newest photo" do
        get user_photo_path(user, newer_photo)
        expect(response.body).not_to include("Previous photo")
        expect(response.body).to include(user_photo_path(user, middle_photo))
      end

      it "shows no next arrow for the oldest photo" do
        get user_photo_path(user, older_photo)
        expect(response.body).to include(user_photo_path(user, middle_photo))
        expect(response.body).not_to include("Next photo")
      end
    end
  end

  describe "POST /:user_id/photos" do
    before { sign_in(user) }

    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )
    end

    it "creates a photo and redirects" do
      expect {
        post user_photos_path(user), params: { photo: { file: file, title: "Sunset" } }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(user_photo_path(user, Photo.last))
    end

    it "renders new on failure" do
      post user_photos_path(user), params: { photo: { title: "No file" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 403 when posting to another user's scope" do
      other_user = FactoryBot.create(:user)
      post user_photos_path(other_user), params: { photo: { file: file, title: "Sunset" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /:user_id/photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "updates and redirects" do
      patch user_photo_path(user, photo), params: { photo: { title: "Updated" } }
      expect(response).to redirect_to(user_photo_path(user, photo))
      expect(photo.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /:user_id/photos/:id" do
    let!(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "destroys the photo and redirects" do
      expect {
        delete user_photo_path(user, photo)
      }.to change(Photo, :count).by(-1)

      expect(response).to redirect_to(user_photos_path(user))
    end
  end
end
