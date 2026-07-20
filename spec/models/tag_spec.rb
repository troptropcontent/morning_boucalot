require "rails_helper"

RSpec.describe Tag do
  subject(:tag) { FactoryBot.build(:tag, name: "Landscape") }

  it "is valid with a name" do
    expect(tag).to be_valid
  end

  it "normalizes name to lowercase on save" do
    tag.save!
    expect(tag.name).to eq("landscape")
  end

  it "is invalid without a name" do
    expect(FactoryBot.build(:tag, name: nil)).not_to be_valid
  end

  it "enforces uniqueness case-insensitively" do
    FactoryBot.create(:tag, name: "landscape")
    expect(FactoryBot.build(:tag, name: "Landscape")).not_to be_valid
  end
end
