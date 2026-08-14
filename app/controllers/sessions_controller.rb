class SessionsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path(tab: "member"), alert: "Try again later." }

  def new
    # Preserve an explicit return_to (e.g. the navbar's "Log in" link on a
    # public page). If there isn't one, leave any return_to already stashed
    # by request_authentication (a protected action bounced here) untouched.
    return_to = safe_return_to(params[:return_to])
    session[:return_to_after_authenticating] = return_to if return_to
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path(tab: "member"), alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_back_or_to root_path, status: :see_other
  end

  private

  # Only accept same-site relative paths — params[:return_to] is
  # attacker-controlled (a crafted link to this endpoint), so an absolute
  # URL here would be an open redirect.
  def safe_return_to(path)
    return nil if path.blank?

    uri = URI.parse(path)
    path if uri.host.nil? && path.start_with?("/") && !path.start_with?("//")
  rescue URI::InvalidURIError
    nil
  end
end
