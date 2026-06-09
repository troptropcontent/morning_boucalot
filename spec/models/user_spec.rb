require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { FactoryBot.build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:photos) }
    it { is_expected.to have_many(:albums) }
  end

  describe "validations" do
    it { is_expected.to be_valid }
    it { is_expected.to have_secure_password }
  end

  describe "email normalization" do
    it "strips and downcases the email address" do
      user = FactoryBot.create(:user, email_address: "  TEST@EXAMPLE.COM  ")
      expect(user.email_address).to eq("test@example.com")
    end
  end
end
