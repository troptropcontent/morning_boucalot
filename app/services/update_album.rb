class UpdateAlbum < ApplicationService
  def initialize(album:, params:)
    @album = album
    @params = params
  end

  def call
    fail!(@album.errors.full_messages) unless @album.update(title: @params[:title], description: @params[:description])
    @album
  end
end
