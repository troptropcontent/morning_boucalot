require "rails_helper"

RSpec.describe PhotoEdits do
  def edits(**options)
    described_class.new(width: 4000, height: 3000, **options)
  end

  describe "#transformations" do
    it "is empty for an unedited photo" do
      expect(edits.transformations).to eq({})
    end

    it "includes the rotation when rotated" do
      expect(edits(rotation: 90).transformations).to eq(rotate: 90)
    end

    it "includes the crop in pixels" do
      expect(edits(crop: [ 0.25, 0.5, 0.5, 0.25 ]).transformations).to eq(crop: [ 1000, 1500, 2000, 750 ])
    end

    it "measures the crop against the rotated image, after rotating" do
      steps = edits(rotation: 90, crop: [ 0.25, 0.5, 0.5, 0.25 ]).transformations

      expect(steps).to eq(rotate: 90, crop: [ 750, 2000, 1500, 1000 ])
      expect(steps.keys).to eq(%i[rotate crop])
    end

    it "leaves the crop out with include_crop: false" do
      expect(edits(rotation: 90, crop: [ 0, 0, 0.5, 0.5 ]).transformations(include_crop: false)).to eq(rotate: 90)
    end

    it "keeps rounded crops inside the image" do
      expect(edits(crop: [ 0.9999999, 0.9999999, 0.0000001, 0.0000001 ]).transformations[:crop]).to eq([ 3999, 2999, 1, 1 ])
    end

    it "needs the image dimensions to crop" do
      expect { described_class.new(crop: [ 0, 0, 1, 1 ]).transformations }.to raise_error(ArgumentError)
    end
  end

  describe "#edited?" do
    it "is false with no edits" do
      expect(edits).not_to be_edited
    end

    it "is true once rotated" do
      expect(edits(rotation: 180)).to be_edited
    end

    it "is true once cropped" do
      expect(edits(crop: [ 0, 0, 0.5, 0.5 ])).to be_edited
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
        expect(edits(rotation: rotation).dimensions).to eq(expected)
      end
    end

    it "is the crop's size once cropped" do
      expect(edits(rotation: 90, crop: [ 0, 0, 0.5, 0.25 ]).dimensions).to eq([ 1500, 1000 ])
    end
  end
end
