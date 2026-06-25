require "rails_helper"

RSpec.describe "Photos", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /photos" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get photos_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "returns 200" do
        get photos_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "returns 200" do
      get photo_path(photo)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's photo" do
      other_photo = FactoryBot.create(:photo)
      get photo_path(other_photo)
      expect(response).to have_http_status(:not_found)
    end

    context "with adjacent photos" do
      let!(:older_photo)  { FactoryBot.create(:photo, user: user, taken_at: 2.days.ago) }
      let!(:middle_photo) { FactoryBot.create(:photo, user: user, taken_at: 1.day.ago) }
      let!(:newer_photo)  { FactoryBot.create(:photo, user: user, taken_at: Time.current) }

      it "shows both arrows for a middle photo" do
        get photo_path(middle_photo)
        expect(response.body).to include(photo_path(newer_photo))
        expect(response.body).to include(photo_path(older_photo))
      end

      it "shows no prev arrow for the newest photo" do
        get photo_path(newer_photo)
        expect(response.body).not_to include("Previous photo")
        expect(response.body).to include(photo_path(middle_photo))
      end

      it "shows no next arrow for the oldest photo" do
        get photo_path(older_photo)
        expect(response.body).to include(photo_path(middle_photo))
        expect(response.body).not_to include("Next photo")
      end
    end
  end

  describe "POST /photos" do
    before { sign_in(user) }

    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )
    end

    it "creates a photo and redirects" do
      expect {
        post photos_path, params: { photo: { file: file, title: "Sunset" } }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(Photo.last)
    end

    it "renders new on failure" do
      post photos_path, params: { photo: { title: "No file" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "updates and redirects" do
      patch photo_path(photo), params: { photo: { title: "Updated" } }
      expect(response).to redirect_to(photo)
      expect(photo.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /photos/:id" do
    let!(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "destroys the photo and redirects" do
      expect {
        delete photo_path(photo)
      }.to change(Photo, :count).by(-1)

      expect(response).to redirect_to(photos_path)
    end
  end
end
