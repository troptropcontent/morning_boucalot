# HTTPS replacement for the FTP offload path -- meant for a future phone
# utility (or curl, for testing) to push camera shots straight to the review
# queue, the same way ScanFtpIncomingJob/IngestOffloadedPhotoJob do for FTP
# uploads. Bearer-token auth instead of session cookies, since the client
# here isn't a logged-in browser. Both paths share IngestOffloadedPhotoFile,
# so a shot lands in the same unpublished review queue either way.
class OffloadUploadsController < ApplicationController
  skip_before_action :resume_session, :require_authentication
  before_action :authenticate_upload_token!

  def create
    owner = OffloadIngestOwner.find
    return render json: { error: "ingest owner not configured" }, status: :service_unavailable unless owner

    file = params[:file]
    return render json: { error: "file is required" }, status: :bad_request unless file.respond_to?(:read)

    result = IngestOffloadedPhotoFile.call(owner: owner, filename: file.original_filename, io: file)

    if result.success?
      render json: { status: "created", id: result.data.id }, status: :created
    elsif result.errors == [ "duplicate" ]
      render json: { status: "duplicate" }, status: :ok
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  private

  # Single shared secret is enough for a single-user app with a single
  # trusted client (the phone utility) -- no per-device tokens or rotation
  # needed. Fails closed if the token isn't configured at all, rather than
  # comparing against a blank string.
  def authenticate_upload_token!
    expected = ENV["OFFLOAD_UPLOAD_TOKEN"]
    return head :service_unavailable if expected.blank?

    provided = request.headers["Authorization"]&.delete_prefix("Bearer ")
    head :unauthorized unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end
end
