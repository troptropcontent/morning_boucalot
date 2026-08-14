class User < ApplicationRecord
  # Guests authenticate via emailed OTP instead of a password, so
  # has_secure_password's own validations (which unconditionally require one)
  # are disabled and reapplied below, gated to members only. Mirrors exactly
  # what has_secure_password itself validates when validations: true.
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_photos, through: :favorites, source: :photo

  enum :role, { member: "member", guest: "guest" }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Only a DB index enforced this before; the guest login flow now relies on
  # find_or_create_by! not silently racing/colliding on email_address, so it
  # needs a real validation, not just the DB constraint underneath it.
  validates :email_address, uniqueness: true
  validate :password_must_be_present, if: :member?
  validate :password_must_not_exceed_bcrypt_limit, if: :member?
  validates :password, confirmation: true, allow_nil: true, if: :member?

  private

  # Checks password_digest, not the virtual password attribute, so updating
  # a member's other fields without resupplying their password still passes.
  def password_must_be_present
    errors.add(:password, :blank) unless password_digest.present?
  end

  def password_must_not_exceed_bcrypt_limit
    return unless password.present?

    errors.add(:password, :password_too_long) if password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
  end
end
