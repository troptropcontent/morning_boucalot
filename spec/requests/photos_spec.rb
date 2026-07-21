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

  describe "GET /:user_id/photos?favorited=1" do
    let!(:favorited_photo) { FactoryBot.create(:photo, user: user, favorited: true) }
    let!(:regular_photo)   { FactoryBot.create(:photo, user: user, favorited: false) }

    it "shows only favorited photos" do
      get user_photos_path(user, favorited: 1)
      expect(response.body).to include(user_photo_path(user, favorited_photo))
      expect(response.body).not_to include(user_photo_path(user, regular_photo))
    end
  end

  describe "PATCH /:user_id/photos/:id/favorite" do
    let(:photo) { FactoryBot.create(:photo, user: user, favorited: false) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "toggles favorited to true and responds with turbo stream" do
        patch favorite_user_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(photo.reload.favorited).to be true
      end

      it "toggles favorited back to false" do
        photo.update!(favorited: true)
        patch favorite_user_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(photo.reload.favorited).to be false
      end

      it "redirects on html format" do
        patch favorite_user_photo_path(user, photo)
        expect(response).to redirect_to(user_photo_path(user, photo))
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch favorite_user_photo_path(user, photo)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated as a different user" do
      it "returns 403" do
        other_user = FactoryBot.create(:user)
        sign_in(other_user)
        patch favorite_user_photo_path(user, photo)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /:user_id/photos/batch" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "adds tags to the selected photos and redirects" do
        patch batch_user_photos_path(user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to redirect_to(user_photos_path(user))
        photos.each { |p| expect(p.reload.tags.map(&:name)).to include("landscape") }
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        patch batch_user_photos_path(other_user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch batch_user_photos_path(user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
