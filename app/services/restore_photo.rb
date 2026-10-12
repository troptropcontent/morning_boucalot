class RestorePhoto < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    @photo.update!(archived_at: nil)
  end
end
