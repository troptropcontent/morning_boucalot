class DeletePhoto < ApplicationService
  def initialize(photo:)
    @photo = photo
  end

  def call
    @photo.destroy
  end
end
