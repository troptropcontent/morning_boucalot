require "rails_helper"

RSpec.describe Photo, type: :model do
  subject(:photo) { FactoryBot.build(:photo) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:photo_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:photo_tags) }
    it { is_expected.to have_many(:favorites).dependent(:destroy) }
    it { is_expected.to have_many(:favorited_by_users).through(:favorites).source(:user) }
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without a file" do
      photo.file.detach
      expect(photo).not_to be_valid
    end

    it "accepts quarter-turn rotations" do
      PhotoEdits::ROTATIONS.each do |rotation|
        photo.rotation = rotation
        expect(photo).to be_valid
      end
    end

    it "rejects other rotations" do
      photo.rotation = 45
      expect(photo).not_to be_valid
      expect(photo.errors[:rotation]).to be_present
    end

    it "accepts straightening angles up to 45° either way" do
      [ -45, -0.5, 0, 12.25, 45 ].each do |angle|
        photo.straighten_angle = angle
        expect(photo).to be_valid
      end
    end

    it "rejects straightening past 45°" do
      photo.straighten_angle = 45.5
      expect(photo).not_to be_valid
      expect(photo.errors[:straighten_angle]).to be_present
    end

    it "is valid with only a raw_file attached" do
      photo.file.detach
      photo.raw_file.attach(io: File.open(Rails.root.join("spec/fixtures/files/test_raw.raf")), filename: "test_raw.raf")
      expect(photo).to be_valid
    end
  end

  describe "#tag_list" do
    it "returns tags as a comma-separated string" do
      photo.save!
      SyncPhotoTags.call(photo: photo, tag_list: "landscape, travel")
      expect(photo.tag_list).to eq("landscape, travel")
    end
  end

  describe ".tagged_with" do
    it "returns photos with the given tag" do
      user = FactoryBot.create(:user)
      tagged = FactoryBot.create(:photo, user: user)
      untagged = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: tagged, tag_list: "landscape")
      SyncPhotoTags.call(photo: untagged, tag_list: "portrait")

      expect(Photo.tagged_with("landscape")).to include(tagged)
      expect(Photo.tagged_with("landscape")).not_to include(untagged)
    end

    it "is case-insensitive" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: photo, tag_list: "landscape")

      expect(Photo.tagged_with("Landscape")).to include(photo)
    end
  end

  describe ".favorited_by" do
    it "returns only photos favorited by the given user" do
      user = FactoryBot.create(:user)
      viewer = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      not_fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: viewer, photo: fav)

      expect(Photo.favorited_by(viewer)).to include(fav)
      expect(Photo.favorited_by(viewer)).not_to include(not_fav)
    end

    it "does not return another user's favorites" do
      user = FactoryBot.create(:user)
      other_user = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: other_user, photo: fav)

      expect(Photo.favorited_by(user)).not_to include(fav)
    end

    it "returns none when no user is given" do
      user = FactoryBot.create(:user)
      fav = FactoryBot.create(:photo, user: user)
      FactoryBot.create(:favorite, user: user, photo: fav)

      expect(Photo.favorited_by(nil)).to be_empty
    end
  end

  describe "#favorited_by?" do
    it "is true once the given user has favorited the photo" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo)
      FactoryBot.create(:favorite, user: user, photo: photo)

      expect(photo.favorited_by?(user)).to be true
    end

    it "is false for a user who hasn't favorited the photo" do
      user = FactoryBot.create(:user)
      photo = FactoryBot.create(:photo)

      expect(photo.favorited_by?(user)).to be false
    end

    it "is false when no user is given" do
      photo = FactoryBot.create(:photo)

      expect(photo.favorited_by?(nil)).to be false
    end
  end

  describe ".recent" do
    it "orders by taken_at descending, then created_at descending" do
      user = FactoryBot.create(:user)
      old_photo = FactoryBot.create(:photo, user: user, taken_at: 2.days.ago)
      new_photo = FactoryBot.create(:photo, user: user, taken_at: 1.day.ago)

      expect(Photo.recent).to eq([ new_photo, old_photo ])
    end
  end

  describe ".published" do
    it "returns only published photos" do
      user = FactoryBot.create(:user)
      published = FactoryBot.create(:photo, user: user)
      unpublished = FactoryBot.create(:photo, user: user, published: false)

      expect(Photo.published).to include(published)
      expect(Photo.published).not_to include(unpublished)
    end
  end

  describe ".unpublished" do
    it "returns only unpublished photos" do
      user = FactoryBot.create(:user)
      published = FactoryBot.create(:photo, user: user)
      unpublished = FactoryBot.create(:photo, user: user, published: false)

      expect(Photo.unpublished).to include(unpublished)
      expect(Photo.unpublished).not_to include(published)
    end
  end

  describe ".active" do
    it "returns only non-archived photos" do
      user = FactoryBot.create(:user)
      active = FactoryBot.create(:photo, user: user)
      archived = FactoryBot.create(:photo, :archived, user: user)

      expect(Photo.active).to include(active)
      expect(Photo.active).not_to include(archived)
    end
  end

  describe ".archived" do
    it "returns only archived photos" do
      user = FactoryBot.create(:user)
      active = FactoryBot.create(:photo, user: user)
      archived = FactoryBot.create(:photo, :archived, user: user)

      expect(Photo.archived).to include(archived)
      expect(Photo.archived).not_to include(active)
    end
  end

  describe "#edits" do
    it "uses the analyzed image's dimensions, not the EXIF columns" do
      photo.save!
      photo.file.blob.analyze
      photo.assign_attributes(rotation: 90, width: 4000, height: 3000)

      expect(photo.edits.rotation).to eq(90)
      expect(photo.edits.dimensions).to eq([ 7728, 5152 ])
    end

    it "carries the straightening angle" do
      photo.straighten_angle = -3.5
      expect(photo.edits.straighten_angle).to eq(-3.5)
    end

    it "carries the crop box" do
      photo.assign_attributes(crop_x: 0.1, crop_y: 0.2, crop_w: 0.5, crop_h: 0.4)
      expect(photo.edits.crop).to eq([ 0.1, 0.2, 0.5, 0.4 ])
    end
  end

  describe "#crop_box" do
    it "is nil without a crop" do
      expect(photo.crop_box).to be_nil
    end

    it "is nil while the crop is incomplete" do
      photo.crop_x = 0.1
      expect(photo.crop_box).to be_nil
    end
  end

  describe "crop validation" do
    def crop(x, y, w, h)
      photo.assign_attributes(crop_x: x, crop_y: y, crop_w: w, crop_h: h)
      photo
    end

    it "accepts no crop" do
      expect(crop(nil, nil, nil, nil)).to be_valid
    end

    it "accepts a box inside the image, up to its edges" do
      expect(crop(0.25, 0.5, 0.75, 0.5)).to be_valid
    end

    it "rejects a partial crop" do
      expect(crop(0.1, 0.1, nil, nil)).not_to be_valid
      expect(photo.errors[:base]).to include("Crop needs a position and a size")
    end

    it "rejects a box past the right edge" do
      expect(crop(0.5, 0, 0.6, 1)).not_to be_valid
      expect(photo.errors[:base]).to include("Crop must lie within the image")
    end

    it "rejects a box past the bottom edge" do
      expect(crop(0, 0.5, 1, 0.6)).not_to be_valid
    end

    it "rejects a negative position" do
      expect(crop(-0.1, 0, 0.5, 0.5)).not_to be_valid
    end

    it "rejects an empty box" do
      expect(crop(0, 0, 0, 0.5)).not_to be_valid
    end
  end

  describe "#image_variant" do
    def operations(variant)
      variant.variation.transformations.except(:format).to_a
    end

    it "uses the plain resize for an unedited photo" do
      expect(operations(photo.image_variant(:thumbnail))).to eq([ [ :resize_to_fill, [ 300, 300 ] ] ])
    end

    # Named variants on the attachment resolve to the same blob.variant call,
    # so an unedited photo's variants keep their digest across the switch.
    it "keeps the variant digest the former named variants used, so cached variants are reused" do
      former = photo.file.blob.variant(resize_to_limit: [ 2400, 2400 ])
      expect(photo.image_variant(:large).variation.digest).to eq(former.variation.digest)
    end

    it "rotates before resizing when the photo is rotated" do
      photo.rotation = 90

      expect(operations(photo.image_variant(:thumbnail))).to eq([ [ :rotate, 90 ], [ :resize_to_fill, [ 300, 300 ] ] ])
    end

    context "when cropped" do
      before do
        photo.save!
        photo.file.blob.analyze
        photo.update!(crop_x: 0.5, crop_y: 0.25, crop_w: 0.5, crop_h: 0.5)
      end

      it "crops in pixels of the original before resizing" do
        expect(operations(photo.image_variant(:large))).to eq([ [ :crop, [ 2576, 1932, 2576, 3864 ] ], [ :resize_to_limit, [ 2400, 2400 ] ] ])
      end

      it "crops after rotating, in pixels of the rotated image" do
        photo.update!(rotation: 90)

        expect(operations(photo.image_variant(:large)).first(2)).to eq([ [ :rotate, 90 ], [ :crop, [ 3864, 1288, 3864, 2576 ] ] ])
      end

      it "leaves the straightening and crop out when asked for the rotation only" do
        photo.update!(rotation: 90, straighten_angle: 2)

        expect(operations(photo.image_variant(:large, only_rotation: true))).to eq([ [ :rotate, 90 ], [ :resize_to_limit, [ 2400, 2400 ] ] ])
      end

      it "straightens in the same rotation, then crops within the straightened area" do
        photo.update!(straighten_angle: -2.5)

        rotate, crop = operations(photo.image_variant(:large)).first(2)
        expect(rotate).to eq([ :rotate, -2.5 ])
        expect(crop.first).to eq(:crop)
        expect(crop.last).to eq(photo.edits.transformations[:crop])
      end

      it "actually straightens the generated image without dark corners" do
        photo.update!(straighten_angle: 5, crop_x: nil, crop_y: nil, crop_w: nil, crop_h: nil)

        image = Vips::Image.new_from_buffer(photo.image_variant(:medium).processed.download, "")
        corners = [ [ 0, 0 ], [ image.width - 4, 0 ], [ 0, image.height - 4 ], [ image.width - 4, image.height - 4 ] ]
        expect(corners.map { |x, y| image.crop(x, y, 4, 4).avg }).to all(be > 40)
      end

      it "actually crops the generated image" do
        image = photo.image_variant(:medium).processed.image
        image.analyze
        # 2576x3864 fitted into 800x600 by height.
        expect(image.metadata.values_at(:width, :height)).to eq([ 400, 600 ])
      end
    end

    it "produces a distinct variant per rotation" do
      unrotated_key = photo.image_variant(:large).variation.key
      photo.rotation = 180

      expect(photo.image_variant(:large).variation.key).not_to eq(unrotated_key)
    end

    it "actually rotates the generated image" do
      photo.rotation = 90
      photo.save!

      # The 5152x7728 fixture becomes 7728x5152, then fits 800x600 by width.
      # Resizing first would give 400x600 turned into 600x400 instead.
      image = photo.image_variant(:medium).processed.image
      image.analyze
      expect(image.metadata.values_at(:width, :height)).to eq([ 800, 533 ])
    end

    it "raises on an unknown variant name" do
      expect { photo.image_variant(:huge) }.to raise_error(KeyError)
    end
  end

  describe "#download" do
    def operations(variant)
      variant.variation.transformations.except(:format).to_a
    end

    it "serves the untouched file blob as the original" do
      expect(photo.download(:original)).to eq(photo.file.blob)
    end

    it "serves the original even once edited" do
      photo.rotation = 90
      expect(photo.download(:original)).to eq(photo.file.blob)
    end

    it "serves the original file for high definition while there are no edits" do
      expect(photo.download(:full)).to eq(photo.file.blob)
    end

    it "serves a full-resolution variant with the edits for high definition once edited" do
      photo.rotation = 90

      expect(operations(photo.download(:full))).to eq([ [ :rotate, 90 ], [ :saver, { quality: 95 } ] ])
    end

    it "serves the large variant, with edits" do
      photo.rotation = 180

      expect(operations(photo.download(:large))).to eq([ [ :rotate, 180 ], [ :resize_to_limit, [ 2400, 2400 ] ] ])
    end

    it "accepts the kind as a string" do
      expect(photo.download("original")).to eq(photo.file.blob)
    end

    it "raises on an unknown kind" do
      expect { photo.download(:thumbnail) }.to raise_error(ArgumentError)
    end

    # libvips drops the orientation tag once it has applied it, but should
    # carry the rest of the camera metadata into the re-encoded file.
    it "keeps the camera EXIF in the high definition file" do
      photo.rotation = 90
      photo.save!

      exif = photo.download(:full).processed.image.blob.open { |tmp| ExtractExifData.call(tmp.path) }

      expect(exif).to include(camera_model: "FUJIFILM X-E5", iso: 200)
      expect(exif[:taken_at]).to be_present
    end
  end

  describe "taken_at defaulting" do
    it "defaults taken_at to now when not provided" do
      photo = FactoryBot.build(:photo, taken_at: nil)

      expect { photo.save! }.to change(photo, :taken_at).from(nil)
      expect(photo.taken_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not override an explicitly set taken_at" do
      taken_at = 3.days.ago
      photo = FactoryBot.create(:photo, taken_at: taken_at)

      expect(photo.taken_at).to be_within(1.second).of(taken_at)
    end
  end
end
