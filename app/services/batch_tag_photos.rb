class BatchTagPhotos < ApplicationService
  def initialize(owner:, photo_ids:, tag_list:)
    @owner = owner
    @photo_ids = Array(photo_ids).map(&:to_i).uniq
    @tag_list = tag_list.to_s
  end

  def call
    fail!([ "No photos selected" ]) if @photo_ids.empty?
    fail!([ "No tags provided" ]) if tag_names.empty?

    photos = @owner.photos.where(id: @photo_ids)
    fail!([ "No matching photos found" ]) if photos.empty?

    ApplicationRecord.transaction do
      photos.each do |photo|
        merged = (photo.tags.map(&:name) + tag_names).uniq.join(", ")
        SyncPhotoTags.new(photo: photo, tag_list: merged).call
      end
    end

    photos
  end

  private

  def tag_names
    @tag_names ||= @tag_list.split(",")
                            .map { |n| Tag.normalize_value_for(:name, n) }
                            .reject(&:empty?)
                            .uniq
  end
end
