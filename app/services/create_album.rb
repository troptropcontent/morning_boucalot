class CreateAlbum < ApplicationService
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    album = @user.albums.build(title: @params[:title], description: @params[:description])
    fail!(album.errors.full_messages) unless album.save
    album
  end
end
