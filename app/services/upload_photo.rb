class UploadPhoto < ApplicationService
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    file = @params[:file]
    fail!([ "File is required" ]) unless file.present?

    photo = @user.photos.build(title: @params[:title], description: @params[:description])
    photo.file.attach(file)
    photo.file_size = file.size

    if PhotoChecksumExists.call(owner: @user, checksum: photo.file.blob.checksum)
      photo.file.blob.purge
      fail!([ "duplicate" ])
    end

    SyncPhotoTags.new(photo: photo, tag_list: @params[:tag_list].to_s).call

    fail!(photo.errors.full_messages) unless photo.save

    ProcessPhotoJob.perform_later(photo.id)

    photo
  end
end
