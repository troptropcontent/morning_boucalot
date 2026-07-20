class SyncPhotoTags < ApplicationService
  def initialize(photo:, tag_list:)
    @photo = photo
    @tag_list = tag_list
  end

  def call
    names = @tag_list.to_s.split(",").map { |n| Tag.normalize_value_for(:name, n) }.reject(&:empty?).uniq
    ApplicationRecord.transaction do
      @photo.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
    end
    @photo
  end
end
