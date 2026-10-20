require "rails_helper"

RSpec.describe PhotoEdits do
  describe "#transformations" do
    it "is empty for an unedited photo" do
      expect(described_class.new(rotation: 0).transformations).to eq({})
    end

    it "includes the rotation when rotated" do
      expect(described_class.new(rotation: 90).transformations).to eq(rotate: 90)
    end
  end

  describe "#edited?" do
    it "is false with no rotation" do
      expect(described_class.new(rotation: 0)).not_to be_edited
    end

    it "is true once rotated" do
      expect(described_class.new(rotation: 180)).to be_edited
    end
  end

  describe "#dimensions" do
    {
      0 => [ 4000, 3000 ],
      90 => [ 3000, 4000 ],
      180 => [ 4000, 3000 ],
      270 => [ 3000, 4000 ]
    }.each do |rotation, expected|
      it "is #{expected.join("x")} for a 4000x3000 original rotated #{rotation}°" do
        edits = described_class.new(rotation: rotation, width: 4000, height: 3000)
        expect(edits.dimensions).to eq(expected)
      end
    end
  end
end
