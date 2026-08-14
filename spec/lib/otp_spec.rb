require "rails_helper"

RSpec.describe Otp do
  describe ".generate" do
    it "returns a numeric code of the configured length" do
      generated = described_class.generate

      expect(generated.code).to match(/\A\d{#{described_class::CODE_LENGTH}}\z/)
    end

    it "returns a challenge with only JSON-safe primitive values, so it round-trips through session storage" do
      generated = described_class.generate

      expect(generated.challenge.keys).to match_array(%w[digest expires_at attempts])
      expect(generated.challenge["digest"]).to be_a(String)
      expect(generated.challenge["expires_at"]).to be_a(Integer)
      expect(generated.challenge["attempts"]).to eq(0)
    end

    it "does not include the code itself in the challenge" do
      generated = described_class.generate

      expect(generated.challenge.values).not_to include(generated.code)
    end
  end

  describe ".verify" do
    it "succeeds with the correct code" do
      generated = described_class.generate

      result = described_class.verify(generated.challenge, generated.code)

      expect(result).to be_success
      expect(result.challenge).to be_nil
    end

    it "fails with an incorrect code and increments the attempt count" do
      generated = described_class.generate

      result = described_class.verify(generated.challenge, "000000")

      expect(result.status).to eq(:incorrect)
      expect(result.challenge["attempts"]).to eq(1)
    end

    it "accumulates the attempt count across repeated failures" do
      generated = described_class.generate
      challenge = generated.challenge

      3.times do
        result = described_class.verify(challenge, "000000")
        challenge = result.challenge
      end

      expect(challenge["attempts"]).to eq(3)
    end

    it "reports too_many_attempts once the limit is reached, even with the correct code" do
      generated = described_class.generate
      exhausted_challenge = generated.challenge.merge("attempts" => described_class::MAX_ATTEMPTS)

      result = described_class.verify(exhausted_challenge, generated.code)

      expect(result.status).to eq(:too_many_attempts)
    end

    it "reports expired once past the expiry time, even with the correct code" do
      generated = described_class.generate(expires_in: -1.second)

      result = described_class.verify(generated.challenge, generated.code)

      expect(result.status).to eq(:expired)
    end

    it "reports expired when there is no challenge at all" do
      result = described_class.verify(nil, "123456")

      expect(result.status).to eq(:expired)
    end

    it "is not fooled by a code that merely matches the same length" do
      generated = described_class.generate

      wrong_code = generated.code == "111111" ? "222222" : "111111"
      result = described_class.verify(generated.challenge, wrong_code)

      expect(result.status).to eq(:incorrect)
    end
  end
end
