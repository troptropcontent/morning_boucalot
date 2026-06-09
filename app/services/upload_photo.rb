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
end
