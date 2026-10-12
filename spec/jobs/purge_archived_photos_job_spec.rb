require "rails_helper"

RSpec.describe PurgeArchivedPhotosJob do
  describe "#perform" do
    it "destroys photos archived more than 60 days ago" do
      old = FactoryBot.create(:photo, :archived, archived_at: 61.days.ago)

      expect { PurgeArchivedPhotosJob.perform_now }.to change(Photo, :count).by(-1)
      expect(Photo.exists?(old.id)).to be false
    end

    it "leaves photos archived less than 60 days ago" do
      recent = FactoryBot.create(:photo, :archived, archived_at: 59.days.ago)

      expect { PurgeArchivedPhotosJob.perform_now }.not_to change(Photo, :count)
      expect(Photo.exists?(recent.id)).to be true
    end

    it "leaves non-archived photos untouched" do
      active = FactoryBot.create(:photo)

      expect { PurgeArchivedPhotosJob.perform_now }.not_to change(Photo, :count)
      expect(Photo.exists?(active.id)).to be true
    end
  end
end
