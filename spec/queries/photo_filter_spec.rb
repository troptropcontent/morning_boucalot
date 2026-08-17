require "rails_helper"

RSpec.describe PhotoFilter do
  let(:user) { FactoryBot.create(:user) }

  describe "#tag" do
    it "is the tag param, presence-cleaned" do
      expect(described_class.new(params: { tag: "landscape" }, user: user).tag).to eq("landscape")
      expect(described_class.new(params: { tag: "" }, user: user).tag).to be_nil
      expect(described_class.new(params: {}, user: user).tag).to be_nil
    end
  end

  describe "#page" do
    it "is the page param, presence-cleaned" do
      expect(described_class.new(params: { page: "2" }, user: user).page).to eq("2")
      expect(described_class.new(params: { page: "" }, user: user).page).to be_nil
      expect(described_class.new(params: {}, user: user).page).to be_nil
    end
  end

  describe "#favoritable?" do
    it "is true when there's a signed-in user" do
      expect(described_class.new(params: {}, user: user).favoritable?).to be true
    end

    it "is false when there's no user" do
      expect(described_class.new(params: {}, user: nil).favoritable?).to be false
    end
  end

  describe "#favorited?" do
    it "is true when requested and there's a user" do
      expect(described_class.new(params: { favorited: "1" }, user: user).favorited?).to be true
    end

    it "is false when requested but there's no user" do
      # e.g. a stale ?favorited=1 link still in the address bar after
      # signing out — must not be treated as an active filter.
      expect(described_class.new(params: { favorited: "1" }, user: nil).favorited?).to be false
    end

    it "is false when not requested, even with a user" do
      expect(described_class.new(params: {}, user: user).favorited?).to be false
    end
  end

  describe "#apply" do
    let!(:tagged_photo)     { FactoryBot.create(:photo, user: user) }
    let!(:favorited_photo)  { FactoryBot.create(:photo, user: user) }
    let!(:plain_photo)      { FactoryBot.create(:photo, user: user) }

    before do
      SyncPhotoTags.call(photo: tagged_photo, tag_list: "landscape")
      FactoryBot.create(:favorite, user: user, photo: favorited_photo)
    end

    it "filters by tag" do
      photos = described_class.new(params: { tag: "landscape" }, user: user).apply(Photo.all)
      expect(photos).to contain_exactly(tagged_photo)
    end

    it "filters by favorited when there's a user" do
      photos = described_class.new(params: { favorited: "1" }, user: user).apply(Photo.all)
      expect(photos).to contain_exactly(favorited_photo)
    end

    it "ignores the favorited param without a user" do
      photos = described_class.new(params: { favorited: "1" }, user: nil).apply(Photo.all)
      expect(photos).to contain_exactly(tagged_photo, favorited_photo, plain_photo)
    end

    it "applies no filters when nothing is requested" do
      photos = described_class.new(params: {}, user: user).apply(Photo.all)
      expect(photos).to contain_exactly(tagged_photo, favorited_photo, plain_photo)
    end
  end

  describe "#to_params" do
    it "carries the tag, resolved favorited state and page forward" do
      expect(described_class.new(params: { tag: "landscape", favorited: "1", page: "2" }, user: user).to_params)
        .to eq(tag: "landscape", favorited: 1, page: "2")
    end

    it "drops favorited when it isn't actually active" do
      expect(described_class.new(params: { favorited: "1" }, user: nil).to_params)
        .to eq(tag: nil, favorited: nil, page: nil)
    end

    it "is nil when there's no page param" do
      expect(described_class.new(params: {}, user: user).to_params)
        .to eq(tag: nil, favorited: nil, page: nil)
    end
  end

  describe "#toggled_params" do
    it "flips favorited on when currently off" do
      expect(described_class.new(params: { tag: "landscape" }, user: user).toggled_params)
        .to eq(tag: "landscape", favorited: 1)
    end

    it "flips favorited off when currently on" do
      expect(described_class.new(params: { favorited: "1" }, user: user).toggled_params)
        .to eq(tag: nil, favorited: nil)
    end

    it "drops the page, landing on page 1 of the new result set" do
      expect(described_class.new(params: { page: "3" }, user: user).toggled_params)
        .to eq(tag: nil, favorited: 1)
    end
  end
end
