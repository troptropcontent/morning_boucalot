class RequestGuestLogin < ApplicationService
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  def initialize(email_address:)
    @email_address = User.normalize_value_for(:email_address, email_address)
  end

  def call
    fail!("Enter an email address.") if @email_address.blank?
    fail!("Enter a valid email address.") unless @email_address.match?(EMAIL_FORMAT)

    generated = Otp.generate

    # A member's email never gets a guest code — logging in as them via OTP
    # would bypass their password entirely. Session state still advances to
    # the "enter code" step regardless, so a prober can't tell member emails
    # apart from unknown ones (same posture PasswordsController already
    # takes: "instructions sent, if a matching user exists").
    GuestOtpMailer.code(@email_address, generated.code).deliver_later unless member_email?

    { "email_address" => @email_address, "challenge" => generated.challenge }
  end

  private

  def member_email?
    User.member.exists?(email_address: @email_address)
  end
end
