class PublishOffloadedPhoto < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    @photo.update!(published: true)
    @photo
  end
end
