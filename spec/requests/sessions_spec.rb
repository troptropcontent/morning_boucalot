require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /session/new" do
    it "renders the login page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end

    it "stashes a safe return_to for after login" do
      get new_session_path(return_to: "/#{user.id}/photos")
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to("/#{user.id}/photos")
    end

    it "ignores an absolute return_to to avoid an open redirect" do
      get new_session_path(return_to: "https://evil.example/steal")
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(user_photos_url(user))
    end

    it "ignores a protocol-relative return_to" do
      get new_session_path(return_to: "//evil.example/steal")
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(user_photos_url(user))
    end

    it "does not clear a return_to already stashed by a protected-page redirect" do
      photo = FactoryBot.create(:photo, user: user)

      get edit_user_photo_path(user, photo) # bounces here, stashes return_to
      get new_session_path                  # visiting login directly afterwards, e.g. via the navbar link
      post session_path, params: { email_address: user.email_address, password: "password123" }

      expect(response).to redirect_to(edit_user_photo_path(user, photo))
    end
  end

  describe "POST /session" do
    it "signs the user in and redirects to their photos by default" do
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(user_photos_path(user))
    end

    it "redirects back to the login page with an alert on bad credentials" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /session" do
    before { sign_in(user) }

    it "signs the user out and returns them to the public page they were on" do
      delete session_path, headers: { "Referer" => user_photos_url(user) }
      expect(response).to redirect_to(user_photos_url(user))
      expect(response).to have_http_status(:see_other)
    end

    it "falls back to the root page when there is no referer" do
      delete session_path
      expect(response).to redirect_to(root_path)
    end
  end
end
