# Pre-flight for the phone utility: "which of these checksums do you already
# have?" so it only uploads files the server doesn't know. Same bearer-token
# auth as OffloadUploadsController.
class OffloadUploadChecksController < ApplicationController
  include OffloadTokenAuthentication

  MAX_CHECKSUMS = 1000

  def create
    owner = OffloadIngestOwner.find
    return render json: { error: "ingest owner not configured" }, status: :service_unavailable unless owner

    checksums = params[:checksums]
    unless checksums.is_a?(Array) && checksums.all?(String)
      return render json: { error: "checksums must be an array of strings" }, status: :bad_request
    end
    if checksums.size > MAX_CHECKSUMS
      return render json: { error: "at most #{MAX_CHECKSUMS} checksums per request" }, status: :bad_request
    end

    render json: { known: KnownPhotoChecksums.call(owner: owner, checksums: checksums) }
  end
end
