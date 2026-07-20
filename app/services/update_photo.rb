class UpdatePhoto < ApplicationService
  def initialize(photo:, params:)
    @photo = photo
    @params = params
  end

  def call
    @photo.assign_attributes(title: @params[:title], description: @params[:description])
    SyncPhotoTags.new(photo: @photo, tag_list: @params[:tag_list]).call if @params.key?(:tag_list)
    fail!(@photo.errors.full_messages) unless @photo.save

    @photo
  end
end
