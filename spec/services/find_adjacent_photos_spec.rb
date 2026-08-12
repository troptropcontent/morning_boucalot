require "rails_helper"

RSpec.describe FindAdjacentPhotos do
  describe ".call" do
    let(:user) { FactoryBot.create(:user) }

    it "finds the previous (more recent) and next (older) photo" do
      older  = FactoryBot.create(:photo, user: user, taken_at: 2.days.ago)
      middle = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago)
      newer  = FactoryBot.create(:photo, user: user, taken_at: Time.current)

      result = FindAdjacentPhotos.call(photo: middle, scope: user.photos.recent).data

      expect(result[:previous_photo]).to eq(newer)
      expect(result[:next_photo]).to eq(older)
    end

    it "returns nil for the previous photo when given the newest photo" do
      middle = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago)
      newer  = FactoryBot.create(:photo, user: user, taken_at: Time.current)

      result = FindAdjacentPhotos.call(photo: newer, scope: user.photos.recent).data

      expect(result[:previous_photo]).to be_nil
      expect(result[:next_photo]).to eq(middle)
    end

    it "returns nil for the next photo when given the oldest photo" do
      older  = FactoryBot.create(:photo, user: user, taken_at: 2.days.ago)
      middle = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago)

      result = FindAdjacentPhotos.call(photo: older, scope: user.photos.recent).data

      expect(result[:previous_photo]).to eq(middle)
      expect(result[:next_photo]).to be_nil
    end

    it "returns nil for both when the photo is the only one in scope" do
      photo = FactoryBot.create(:photo, user: user)

      result = FindAdjacentPhotos.call(photo: photo, scope: user.photos.recent).data

      expect(result[:previous_photo]).to be_nil
      expect(result[:next_photo]).to be_nil
    end

    it "respects a filtered scope, ignoring photos outside it" do
      nature_tag = FactoryBot.create(:tag, name: "nature")
      tagged_older  = FactoryBot.create(:photo, user: user, taken_at: 2.days.ago,  tags: [ nature_tag ])
      tagged_middle = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago,   tags: [ nature_tag ])
      FactoryBot.create(:photo, user: user, taken_at: 12.hours.ago) # untagged, closer to tagged_middle

      scope = user.photos.recent.tagged_with("nature")
      result = FindAdjacentPhotos.call(photo: tagged_middle, scope: scope).data

      expect(result[:previous_photo]).to be_nil
      expect(result[:next_photo]).to eq(tagged_older)
    end

    it "breaks ties on identical taken_at using id, newest id first" do
      timestamp = 1.day.ago
      first  = FactoryBot.create(:photo, user: user, taken_at: timestamp)
      second = FactoryBot.create(:photo, user: user, taken_at: timestamp)

      result = FindAdjacentPhotos.call(photo: first, scope: user.photos.recent).data

      expect(result[:previous_photo]).to eq(second)
      expect(result[:next_photo]).to be_nil
    end
  end
end
