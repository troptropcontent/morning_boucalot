class GuestOtpMailer < ApplicationMailer
  def code(email_address, code)
    @code = code
    mail subject: "Your login code", to: email_address
  end
end
