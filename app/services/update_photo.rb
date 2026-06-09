class UpdatePhoto < ApplicationService
  def initialize(photo:, params:)
    @photo = photo
    @params = params
  end

  def call
    fail!(@photo.errors.full_messages) unless @photo.update(title: @params[:title], description: @params[:description])

    @photo
  end
end
