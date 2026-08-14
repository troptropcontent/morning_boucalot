require "rails_helper"

RSpec.describe GuestOtpMailer, type: :mailer do
  describe "#code" do
    let(:mail) { described_class.code("guest@example.com", "483920") }

    it "is addressed to the given email" do
      expect(mail.to).to eq([ "guest@example.com" ])
    end

    it "has a subject" do
      expect(mail.subject).to eq("Your login code")
    end

    it "includes the code in the html body" do
      expect(mail.html_part.body.to_s).to include("483920")
    end

    it "includes the code in the text body" do
      expect(mail.text_part.body.to_s).to include("483920")
    end
  end
end
