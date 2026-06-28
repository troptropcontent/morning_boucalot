class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if authenticated?
      redirect_to user_photos_path(Current.user)
    else
      redirect_to new_session_path
    end
  end
end
