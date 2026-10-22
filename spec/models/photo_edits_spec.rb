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

    it "keeps only the quarter turns with only_rotation: true" do
      steps = edits(rotation: 90, straighten_angle: 3, crop: [ 0, 0, 0.5, 0.5 ]).transformations(only_rotation: true)

      expect(steps).to eq(rotate: 90)
    end

    it "is empty with only_rotation: true for a photo that isn't turned" do
      expect(edits(straighten_angle: 3).transformations(only_rotation: true)).to eq({})
    end

    context "when straightened" do
      # 4000x3000 tilted 10° needs a 4460x3649 canvas; the largest 4:3
      # rectangle inside the tilted image is 3288x2466 (scale 0.822), less
      # the 2px inset on each side, centered on that canvas.
      it "rotates by the angle and crops away the empty corners" do
        expect(edits(straighten_angle: 10).transformations).to eq(rotate: 10.0, crop: [ 588, 594, 3284, 2462 ])
      end

      it "crops the same area whichever way it tilts" do
        expect(edits(straighten_angle: -10).transformations).to eq(rotate: -10.0, crop: [ 588, 594, 3284, 2462 ])
      end

      it "folds the quarter turns into the same rotation" do
        expect(edits(rotation: 90, straighten_angle: 10).transformations).to eq(rotate: 100.0, crop: [ 594, 588, 2462, 3284 ])
      end

      it "measures the user's crop against the straightened area" do
        steps = edits(straighten_angle: 10, crop: [ 0.5, 0.5, 0.5, 0.5 ]).transformations

        expect(steps).to eq(rotate: 10.0, crop: [ 588 + 1642, 594 + 1231, 1642, 1231 ])
        expect(steps.keys).to eq(%i[rotate crop])
      end
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

    it "is true once straightened" do
      expect(edits(straighten_angle: -0.5)).to be_edited
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

    it "is the straightened area's size once straightened" do
      expect(edits(straighten_angle: 10).dimensions).to eq([ 3284, 2462 ])
    end

    it "is the crop's size once cropped" do
      expect(edits(rotation: 90, crop: [ 0, 0, 0.5, 0.25 ]).dimensions).to eq([ 1500, 1000 ])
    end
  end
end
