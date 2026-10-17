# Bearer-token auth shared by the phone-utility endpoints (upload + checksum
# pre-check). Single shared secret is enough for a single-user app with a
# single trusted client -- no per-device tokens or rotation needed. Fails
# closed if the token isn't configured at all, rather than comparing against
# a blank string.
module OffloadTokenAuthentication
  extend ActiveSupport::Concern

  included do
    skip_before_action :resume_session, :require_authentication
    before_action :authenticate_upload_token!
  end

  private

  def authenticate_upload_token!
    expected = ENV["OFFLOAD_UPLOAD_TOKEN"]
    return head :service_unavailable if expected.blank?

    provided = request.headers["Authorization"]&.delete_prefix("Bearer ")
    head :unauthorized unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
