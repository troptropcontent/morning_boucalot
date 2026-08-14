class GuestSessionsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path(tab: "guest"), alert: "Try again later." }
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to new_session_path(tab: "guest"), alert: "Try again later." }
  before_action :require_pending_login, only: %i[edit update]

  def create
    result = RequestGuestLogin.call(email_address: params[:email_address])

    respond_to do |format|
      if result.success?
        session[:guest_otp] = result.data
        # Swaps the email form for the code form in place, inside the
        # guest_login frame on the login page — no navigation.
        format.turbo_stream { render turbo_stream: turbo_stream.update("guest_login", partial: "guest_sessions/code_form") }
        format.html { redirect_to edit_guest_session_path }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: nil, alert: result.errors.join(", ") })
        end
        format.html { redirect_to new_session_path(tab: "guest"), alert: result.errors.join(", ") }
      end
    end
  end

  def edit
  end

  # :success and the lockout cases (:expired, :too_many_attempts) leave the
  # code step entirely, so they redirect same as the rest of this app's
  # non-frame auth forms. :incorrect is a routine retry — the visitor is
  # about to try again on the very same screen — so it stays put and updates
  # the guest_login frame in place via Turbo Stream instead of round-tripping
  # through a full top-level redirect.
  def update
    outcome = VerifyGuestLogin.call(session_data: session[:guest_otp], code: params[:code]).data

    case outcome.status
    when :success
      session.delete(:guest_otp)
      start_new_session_for(outcome.user)
      redirect_to after_authentication_url
    when :incorrect
      session[:guest_otp]["challenge"] = outcome.challenge
      alert = "Incorrect code. #{attempts_remaining(outcome.challenge)} left."
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("guest_login", partial: "guest_sessions/code_form"),
            turbo_stream.update("flash", partial: "layouts/flash", locals: { notice: nil, alert: alert })
          ]
        end
        format.html { redirect_to edit_guest_session_path, alert: alert }
      end
    else # :expired, :too_many_attempts
      session.delete(:guest_otp)
      redirect_to new_session_path(tab: "guest"), alert: "That code is no longer valid. Request a new one."
    end
  end

  # Lets a visitor back out of a pending code screen — e.g. to fix a typo'd
  # email or request a fresh code — without waiting out MAX_ATTEMPTS. Safe to
  # call with no pending login (it's just a no-op session clear).
  def destroy
    session.delete(:guest_otp)
    redirect_to new_session_path(tab: "guest")
  end

  private

  def require_pending_login
    redirect_to new_session_path(tab: "guest"), alert: "Request a code first." unless session[:guest_otp]
  end

  def attempts_remaining(challenge)
    remaining = Otp::MAX_ATTEMPTS - challenge["attempts"]
    "#{remaining} attempt#{"s" unless remaining == 1}"
  end
end
