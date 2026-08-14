# A one-time numeric code, generated server-side and verified against a
# caller-held "challenge" — a plain Hash of JSON-safe values (string keys,
# primitives only) so it round-trips cleanly through Rails' session cookie
# regardless of which message serializer is configured. This class never
# persists anything itself; callers are responsible for storing the
# challenge between generate and verify (e.g. in session[...]) and for
# discarding it once verification succeeds or attempts are exhausted.
class Otp
  CODE_LENGTH = 6
  MAX_ATTEMPTS = 5
  DEFAULT_EXPIRES_IN = 10.minutes

  Generated = Struct.new(:code, :challenge, keyword_init: true)
  Result = Struct.new(:status, :challenge, keyword_init: true) do
    def success?
      status == :success
    end
  end

  class << self
    def generate(expires_in: DEFAULT_EXPIRES_IN)
      code = format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
      challenge = { "digest" => digest_for(code), "expires_at" => expires_in.from_now.to_i, "attempts" => 0 }
      Generated.new(code: code, challenge: challenge)
    end

    # challenge is whatever generate previously returned (possibly round-tripped
    # through session storage). Returns a Result with status :success, :incorrect,
    # :expired, or :too_many_attempts. On :incorrect, result.challenge carries the
    # attempt count incremented — callers must persist it back to make it stick.
    def verify(challenge, code)
      return Result.new(status: :expired, challenge: nil) if challenge.blank?
      return Result.new(status: :expired, challenge: challenge) if Time.at(challenge["expires_at"].to_i).past?
      return Result.new(status: :too_many_attempts, challenge: challenge) if challenge["attempts"].to_i >= MAX_ATTEMPTS

      if ActiveSupport::SecurityUtils.secure_compare(digest_for(code.to_s), challenge["digest"].to_s)
        Result.new(status: :success, challenge: nil)
      else
        updated_challenge = challenge.merge("attempts" => challenge["attempts"].to_i + 1)
        Result.new(status: :incorrect, challenge: updated_challenge)
      end
    end

    private

    def digest_for(code)
      Digest::SHA256.hexdigest(code)
    end
  end
end
