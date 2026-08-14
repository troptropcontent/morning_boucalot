require "rails_helper"

RSpec.describe "GuestSessions", type: :request do
  include ActiveJob::TestHelper

  def request_login_and_capture_code(email_address)
    perform_enqueued_jobs { post guest_session_path, params: { email_address: email_address } }
    ActionMailer::Base.deliveries.last.html_part.body.to_s[/\d{6}/]
  end

  describe "POST /guest_session" do
    it "redirects to the code step on html format" do
      post guest_session_path, params: { email_address: "guest@example.com" }

      expect(response).to redirect_to(edit_guest_session_path)
    end

    it "sends an email containing a code" do
      expect {
        perform_enqueued_jobs { post guest_session_path, params: { email_address: "guest@example.com" } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "guest@example.com" ])
    end

    it "swaps in the code form on turbo stream format" do
      post guest_session_path, params: { email_address: "guest@example.com" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="guest_login"')
      expect(response.body).to include("Verify")
    end

    it "does not create a User yet" do
      expect {
        post guest_session_path, params: { email_address: "guest@example.com" }
      }.not_to change(User, :count)
    end

    it "redirects back to the guest tab with an alert on a blank email" do
      post guest_session_path, params: { email_address: "" }

      expect(response).to redirect_to(new_session_path(tab: "guest"))
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /guest_session/edit" do
    it "redirects to the guest tab when there is no pending login" do
      get edit_guest_session_path

      expect(response).to redirect_to(new_session_path(tab: "guest"))
    end

    it "renders the code form when a login is pending" do
      post guest_session_path, params: { email_address: "guest@example.com" }

      get edit_guest_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Verify")
    end
  end

  describe "PATCH /guest_session" do
    it "signs in and creates a guest user on the correct code" do
      code = request_login_and_capture_code("guest@example.com")

      expect {
        patch guest_session_path, params: { code: code }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(user_photos_path(User.last))
      expect(User.last).to be_guest
      expect(User.last.email_address).to eq("guest@example.com")
    end

    it "logs an existing guest back in without creating a duplicate" do
      FactoryBot.create(:user, :guest, email_address: "guest@example.com")
      code = request_login_and_capture_code("guest@example.com")

      expect {
        patch guest_session_path, params: { code: code }
      }.not_to change(User, :count)
    end

    it "redirects back to the code step with an alert on an incorrect code, without creating a user" do
      request_login_and_capture_code("guest@example.com")

      expect {
        patch guest_session_path, params: { code: "000000" }
      }.not_to change(User, :count)

      expect(response).to redirect_to(edit_guest_session_path)
      expect(flash[:alert]).to include("Incorrect code")
    end

    it "updates the guest_login frame and flash in place on turbo stream format, without redirecting" do
      request_login_and_capture_code("guest@example.com")

      patch guest_session_path, params: { code: "000000" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="guest_login"')
      expect(response.body).to include('target="flash"')
      expect(response.body).to include("Incorrect code")
      expect(response.body).to include("Verify")
    end

    it "allows retrying after an incorrect code" do
      code = request_login_and_capture_code("guest@example.com")
      patch guest_session_path, params: { code: "000000" }

      patch guest_session_path, params: { code: code }

      expect(response).to redirect_to(user_photos_path(User.last))
    end

    it "redirects to the guest tab once the attempt cap is exhausted" do
      request_login_and_capture_code("guest@example.com")

      # MAX_ATTEMPTS wrong guesses bring the count up to the cap (each still
      # reported as :incorrect); the next one is the first to see the cap
      # already reached and reports :too_many_attempts.
      Otp::MAX_ATTEMPTS.times { patch guest_session_path, params: { code: "000000" } }
      patch guest_session_path, params: { code: "000000" }

      expect(response).to redirect_to(new_session_path(tab: "guest"))
      expect(flash[:alert]).to match(/no longer valid/)
    end

    it "redirects to the guest tab when there is no pending login" do
      patch guest_session_path, params: { code: "123456" }

      expect(response).to redirect_to(new_session_path(tab: "guest"))
    end

    it "does not let a guest login bypass an existing member's password" do
      FactoryBot.create(:user, email_address: "member@example.com")
      # No code is ever emailed for a member's address (see RequestGuestLogin
      # spec) — nobody ever learns the real one, so any guess against the
      # live challenge fails.
      post guest_session_path, params: { email_address: "member@example.com" }

      patch guest_session_path, params: { code: "123456" }

      expect(response).to redirect_to(edit_guest_session_path)
      expect(flash[:alert]).to include("Incorrect code")
    end
  end

  describe "DELETE /guest_session" do
    it "clears the pending login and redirects to the guest tab" do
      post guest_session_path, params: { email_address: "guest@example.com" }

      delete guest_session_path

      expect(response).to redirect_to(new_session_path(tab: "guest"))

      get edit_guest_session_path
      expect(response).to redirect_to(new_session_path(tab: "guest"))
    end

    it "is a safe no-op when there is no pending login" do
      delete guest_session_path

      expect(response).to redirect_to(new_session_path(tab: "guest"))
    end
  end

  describe "signing in as a guest" do
    def sign_in_as_guest(email_address)
      code = request_login_and_capture_code(email_address)
      patch guest_session_path, params: { code: code }
      User.last
    end

    it "cannot upload, edit, delete, batch-tag, or download-zip even on their own gallery URL" do
      guest = sign_in_as_guest("guest@example.com")
      photo = FactoryBot.create(:photo, user: guest)

      expect(post(user_photos_path(guest), params: { photo: { title: "x" } })).to eq(403)
      expect(patch(user_photo_path(guest, photo), params: { photo: { title: "x" } })).to eq(403)
      expect(delete(user_photo_path(guest, photo))).to eq(403)
      expect(patch(batch_user_photos_path(guest), params: { photo_ids: [ photo.id ] })).to eq(403)
      expect(post(download_zip_user_photos_path(guest), params: { photo_ids: [ photo.id ] })).to eq(403)
    end

    it "can still favorite photos" do
      guest = sign_in_as_guest("guest@example.com")
      photo = FactoryBot.create(:photo)

      patch favorite_user_photo_path(photo.user, photo)

      expect(photo.favorited_by?(guest)).to be true
    end

    it "does not see the navbar's Upload link, unlike a member" do
      guest = sign_in_as_guest("guest@example.com")

      get user_photos_path(guest)

      expect(response.body).not_to include("+ Upload")
    end
  end
end
