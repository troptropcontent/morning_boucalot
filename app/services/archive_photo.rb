class ArchivePhoto < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    @photo.update!(archived_at: Time.current)
  end
end
