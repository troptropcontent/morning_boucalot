require "rails_helper"

RSpec.describe "ArchivedPhotos", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /:user_id/trash" do
    let!(:archived) { FactoryBot.create(:photo, :archived, user: user) }
    let!(:active) { FactoryBot.create(:photo, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "returns 200 and lists only archived photos" do
        get user_archived_photos_path(user)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(id="photo_#{archived.id}"))
        expect(response.body).not_to include(%(id="photo_#{active.id}"))
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get user_archived_photos_path(user)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated as a different user" do
      it "returns 403" do
        sign_in(FactoryBot.create(:user))
        get user_archived_photos_path(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /:user_id/trash/:id/restore" do
    let!(:photo) { FactoryBot.create(:photo, :archived, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "clears archived_at and redirects" do
        patch restore_user_archived_photo_path(user, photo)
        expect(photo.reload.archived_at).to be_nil
        expect(response).to redirect_to(user_archived_photos_path(user))
      end

      it "makes the photo show up in the main gallery again" do
        patch restore_user_archived_photo_path(user, photo)
        get user_photos_path(user)
        expect(response.body).to include(user_photo_path(user, photo))
      end
    end

    context "when authenticated as a different user" do
      it "returns 403 and does not restore" do
        sign_in(FactoryBot.create(:user))
        patch restore_user_archived_photo_path(user, photo)
        expect(response).to have_http_status(:forbidden)
        expect(photo.reload.archived_at).to be_present
      end
    end
  end

  describe "DELETE /:user_id/trash/:id" do
    let!(:photo) { FactoryBot.create(:photo, :archived, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "permanently destroys the photo" do
        expect {
          delete user_archived_photo_path(user, photo)
        }.to change(Photo, :count).by(-1)
        expect(response).to redirect_to(user_archived_photos_path(user))
      end
    end

    context "when authenticated as a different user" do
      it "returns 403 and does not destroy" do
        sign_in(FactoryBot.create(:user))
        expect {
          delete user_archived_photo_path(user, photo)
        }.not_to change(Photo, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /:user_id/trash/batch_restore" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, :archived, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "restores the selected photos and redirects" do
        patch batch_restore_user_archived_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to redirect_to(user_archived_photos_path(user))
        photos.each { |p| expect(p.reload.archived_at).to be_nil }
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        patch batch_restore_user_archived_photos_path(other_user), params: { photo_ids: photos.map(&:id) }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch batch_restore_user_archived_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /:user_id/trash" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, :archived, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "permanently destroys the selected photos and redirects" do
        expect {
          delete user_archived_photos_path(user), params: { photo_ids: photos.map(&:id) }
        }.to change(Photo, :count).by(-2)
        expect(response).to redirect_to(user_archived_photos_path(user))
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        delete user_archived_photos_path(other_user), params: { photo_ids: photos.map(&:id) }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        delete user_archived_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
