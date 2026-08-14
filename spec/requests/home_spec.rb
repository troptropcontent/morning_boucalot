require "rails_helper"

RSpec.describe "Home", type: :request do
  include ActiveJob::TestHelper

  def sign_in_as_guest(email_address)
    perform_enqueued_jobs { post guest_session_path, params: { email_address: email_address } }
    code = ActionMailer::Base.deliveries.last.html_part.body.to_s[/\d{6}/]
    patch guest_session_path, params: { code: code }
    User.last
  end

  describe "GET /" do
    it "redirects an unauthenticated visitor to sign in" do
      get root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "redirects a member to their own gallery" do
      member = FactoryBot.create(:user)
      sign_in(member)

      get root_path

      expect(response).to redirect_to(user_photos_path(member))
    end

    it "redirects a guest to the member's gallery, not their own" do
      member = FactoryBot.create(:user)
      guest = sign_in_as_guest("guest@example.com")

      get root_path

      expect(response).to redirect_to(user_photos_path(member))
      expect(response).not_to redirect_to(user_photos_path(guest))
    end
  end
end
