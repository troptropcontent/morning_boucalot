# HTTPS replacement for the FTP offload path -- meant for a future phone
# utility (or curl, for testing) to push camera shots straight to the review
# queue, the same way ScanFtpIncomingJob/IngestOffloadedPhotoJob do for FTP
# uploads. Bearer-token auth instead of session cookies, since the client
# here isn't a logged-in browser. Both paths share IngestOffloadedPhotoFile,
# so a shot lands in the same unpublished review queue either way.
class OffloadUploadsController < ApplicationController
  include OffloadTokenAuthentication

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
end
