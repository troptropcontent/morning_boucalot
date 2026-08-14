class VerifyGuestLogin < ApplicationService
  # Always returns a successful ServiceResult — "wrong code" and "expired"
  # are expected outcomes the controller needs full detail on (which
  # challenge to write back to session, how many attempts are left), not
  # exceptional failures. Callers branch on outcome.status.
  Outcome = Struct.new(:status, :challenge, :user, keyword_init: true) do
    def success?
      status == :success
    end
  end

  def initialize(session_data:, code:)
    @email_address = session_data && session_data["email_address"]
    @challenge = session_data && session_data["challenge"]
    @code = code.to_s
  end

  def call
    result = Otp.verify(@challenge, @code)

    if result.success?
      Outcome.new(status: :success, challenge: nil, user: find_or_create_guest!)
    else
      Outcome.new(status: result.status, challenge: result.challenge, user: nil)
    end
  end

  private

  def find_or_create_guest!
    User.find_or_create_by!(email_address: @email_address) { |user| user.role = :guest }
  end
end
