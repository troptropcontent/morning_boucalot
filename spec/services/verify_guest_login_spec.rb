require "rails_helper"

RSpec.describe VerifyGuestLogin do
  include ActiveJob::TestHelper

  # RequestGuestLogin only ever exposes the challenge (a digest) — the real
  # code has to be pulled out of the email it sends.
  def request_login_and_capture_code(email_address)
    session_data = nil
    perform_enqueued_jobs { session_data = RequestGuestLogin.call(email_address: email_address).data }
    code = ActionMailer::Base.deliveries.last.html_part.body.to_s[/\d{6}/]
    [ session_data, code ]
  end

  describe ".call" do
    it "creates a guest user and returns it on a correct code" do
      session_data, code = request_login_and_capture_code("guest@example.com")

      result = nil
      expect {
        result = described_class.call(session_data: session_data, code: code)
      }.to change(User, :count).by(1)

      expect(result.data).to be_success
      expect(result.data.user.email_address).to eq("guest@example.com")
      expect(result.data.user).to be_guest
      expect(result.data.challenge).to be_nil
    end

    it "logs an existing guest back in without creating a duplicate" do
      FactoryBot.create(:user, :guest, email_address: "guest@example.com")
      session_data, code = request_login_and_capture_code("guest@example.com")

      expect {
        described_class.call(session_data: session_data, code: code)
      }.not_to change(User, :count)
    end

    it "returns :incorrect with an updated challenge on a wrong code, without creating a user" do
      session_data, _code = request_login_and_capture_code("guest@example.com")

      result = nil
      expect {
        result = described_class.call(session_data: session_data, code: "000000")
      }.not_to change(User, :count)

      expect(result.data.status).to eq(:incorrect)
      expect(result.data.challenge["attempts"]).to eq(1)
      expect(result.data.user).to be_nil
    end

    it "returns :expired when there is no session data at all" do
      result = described_class.call(session_data: nil, code: "123456")

      expect(result.data.status).to eq(:expired)
    end

    it "returns :too_many_attempts once the attempt cap is reached" do
      session_data, _code = request_login_and_capture_code("guest@example.com")
      session_data["challenge"]["attempts"] = Otp::MAX_ATTEMPTS

      result = described_class.call(session_data: session_data, code: "000000")

      expect(result.data.status).to eq(:too_many_attempts)
    end
  end
end
