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

    if checksum_exists?(photo.file.blob.checksum)
      photo.file.blob.purge
      fail!([ "duplicate" ])
    end

    SyncPhotoTags.new(photo: photo, tag_list: @params[:tag_list].to_s).call

    if jpeg?(file.content_type)
      exif = ExtractExifData.call(local_path(file))
      photo.assign_attributes(exif) if exif.any?
    end

    fail!(photo.errors.full_messages) unless photo.save

    photo
  end

  private

  def jpeg?(content_type)
    content_type.in?(%w[image/jpeg image/jpg])
  end

  def local_path(file)
    file.respond_to?(:path) ? file.path : file.tempfile.path
  end

  def checksum_exists?(checksum)
    ActiveStorage::Blob
      .where(checksum: checksum)
      .joins(:attachments)
      .where(active_storage_attachments: { record_type: "Photo", name: "file", record_id: @user.photos.select(:id) })
      .exists?
  end
end
