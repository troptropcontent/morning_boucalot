require "rails_helper"

RSpec.describe Album, type: :model do
  subject(:album) { FactoryBot.build(:album) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:cover_photo).optional }
    it { is_expected.to have_many(:album_photos).dependent(:destroy) }
    it { is_expected.to have_many(:photos).through(:album_photos) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
  end
end
