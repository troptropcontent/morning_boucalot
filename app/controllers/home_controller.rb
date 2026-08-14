class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if authenticated?
      owner = FindDefaultGalleryOwnerForUser.call(user: Current.user).data
      redirect_to user_photos_path(owner)
    else
      redirect_to new_session_path
    end
  end
end
