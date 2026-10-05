require "rails_helper"

RSpec.describe "OffloadedPhotos", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /:user_id/offloaded_photos" do
    let!(:unpublished) { FactoryBot.create(:photo, user: user, published: false) }
    let!(:published) { FactoryBot.create(:photo, user: user, published: true) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "returns 200 and lists only unpublished photos" do
        get user_offloaded_photos_path(user)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(id="photo_#{unpublished.id}"))
        expect(response.body).not_to include(%(id="photo_#{published.id}"))
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get user_offloaded_photos_path(user)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated as a different user" do
      it "returns 403" do
        sign_in(FactoryBot.create(:user))
        get user_offloaded_photos_path(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /:user_id/offloaded_photos/:id" do
    let!(:photo) { FactoryBot.create(:photo, user: user, published: false, taken_at: 2.days.ago) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "returns 200 and renders the photo as a full page" do
        get user_offloaded_photo_path(user, photo)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Back")
      end

      it "links to the next older unpublished photo but not a previous one" do
        older = FactoryBot.create(:photo, user: user, published: false, taken_at: 3.days.ago)
        get user_offloaded_photo_path(user, photo)
        expect(response.body).to include(user_offloaded_photo_path(user, older))
        expect(response.body).not_to include(%(aria-label="Previous photo"))
      end

      it "links to the previous newer unpublished photo but not a next one" do
        newer = FactoryBot.create(:photo, user: user, published: false, taken_at: 1.day.ago)
        get user_offloaded_photo_path(user, photo)
        expect(response.body).to include(user_offloaded_photo_path(user, newer))
        expect(response.body).not_to include(%(aria-label="Next photo"))
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get user_offloaded_photo_path(user, photo)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated as a different user" do
      it "returns 403" do
        sign_in(FactoryBot.create(:user))
        get user_offloaded_photo_path(user, photo)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /:user_id/offloaded_photos/:id/publish" do
    let!(:photo) { FactoryBot.create(:photo, user: user, published: false) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "publishes the photo and redirects on html format" do
        patch publish_user_offloaded_photo_path(user, photo)
        expect(photo.reload.published).to be true
        expect(response).to redirect_to(user_offloaded_photos_path(user))
      end

      it "removes the card via turbo stream" do
        patch publish_user_offloaded_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(target="photo_#{photo.id}"))
      end

      it "makes the photo show up in the main gallery afterwards" do
        patch publish_user_offloaded_photo_path(user, photo)
        get user_photos_path(user)
        expect(response.body).to include(user_photo_path(user, photo))
      end

      it "redirects to the next unpublished photo when one exists" do
        older = FactoryBot.create(:photo, user: user, published: false, taken_at: photo.taken_at - 1.day)
        patch publish_user_offloaded_photo_path(user, photo)
        expect(response).to redirect_to(user_offloaded_photo_path(user, older))
      end

      it "still redirects when navigating from the full-page viewer, even though the browser also accepts turbo-stream" do
        older = FactoryBot.create(:photo, user: user, published: false, taken_at: photo.taken_at - 1.day)
        patch publish_user_offloaded_photo_path(user, photo),
              params: { navigate: true },
              headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
        expect(response).to redirect_to(user_offloaded_photo_path(user, older))
      end
    end

    context "when authenticated as a different user" do
      it "returns 403 and does not publish" do
        sign_in(FactoryBot.create(:user))
        patch publish_user_offloaded_photo_path(user, photo)
        expect(response).to have_http_status(:forbidden)
        expect(photo.reload.published).to be false
      end
    end
  end

  describe "DELETE /:user_id/offloaded_photos/:id/discard" do
    let!(:photo) { FactoryBot.create(:photo, user: user, published: false) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "destroys the photo and redirects to the index when none remain" do
        expect {
          delete discard_user_offloaded_photo_path(user, photo)
        }.to change(Photo, :count).by(-1)
        expect(response).to redirect_to(user_offloaded_photos_path(user))
      end

      it "redirects to the next unpublished photo when one exists" do
        older = FactoryBot.create(:photo, user: user, published: false, taken_at: photo.taken_at - 1.day)
        delete discard_user_offloaded_photo_path(user, photo)
        expect(response).to redirect_to(user_offloaded_photo_path(user, older))
      end

      it "still redirects when navigating from the full-page viewer, even though the browser also accepts turbo-stream" do
        older = FactoryBot.create(:photo, user: user, published: false, taken_at: photo.taken_at - 1.day)
        delete discard_user_offloaded_photo_path(user, photo),
               params: { navigate: true },
               headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
        expect(response).to redirect_to(user_offloaded_photo_path(user, older))
      end
    end

    context "when authenticated as a different user" do
      it "returns 403 and does not destroy the photo" do
        sign_in(FactoryBot.create(:user))
        expect {
          delete discard_user_offloaded_photo_path(user, photo)
        }.not_to change(Photo, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
