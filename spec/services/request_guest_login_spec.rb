require "rails_helper"

RSpec.describe RequestGuestLogin do
  describe ".call" do
    it "sends a code and returns session data with the normalized email and a fresh challenge" do
      result = nil
      expect {
        result = described_class.call(email_address: "  Guest@Example.com  ")
      }.to have_enqueued_mail(GuestOtpMailer, :code)

      expect(result).to be_success
      expect(result.data["email_address"]).to eq("guest@example.com")
      expect(result.data["challenge"]).to include("digest", "expires_at", "attempts")
    end

    it "does not create a User yet" do
      expect {
        described_class.call(email_address: "guest@example.com")
      }.not_to change(User, :count)
    end

    it "fails on a blank email address" do
      result = described_class.call(email_address: "")
      expect(result).to be_failure
    end

    it "fails on a malformed email address" do
      result = described_class.call(email_address: "not-an-email")
      expect(result).to be_failure
    end

    context "when the email belongs to an existing member" do
      let!(:member) { FactoryBot.create(:user, email_address: "member@example.com") }

      it "does not send a code" do
        expect {
          described_class.call(email_address: "member@example.com")
        }.not_to have_enqueued_mail(GuestOtpMailer, :code)
      end

      it "still returns session data indistinguishable from an unknown email, so probing can't tell them apart" do
        result = described_class.call(email_address: "member@example.com")

        expect(result).to be_success
        expect(result.data["email_address"]).to eq("member@example.com")
        expect(result.data["challenge"]).to include("digest", "expires_at", "attempts")
      end
    end

    context "when the email already belongs to an existing guest" do
      it "still sends a code (returning guests log back in the same way)" do
        FactoryBot.create(:user, :guest, email_address: "guest@example.com")

        expect {
          described_class.call(email_address: "guest@example.com")
        }.to have_enqueued_mail(GuestOtpMailer, :code)
      end
    end
  end
end
