# Presign step of the phone's RAF offload: the RAF itself goes phone -> S3,
# never through Rails. AttachRafsJob links the object to its photo later.
class RafUploadsController < ApplicationController
  include OffloadTokenAuthentication

  def presign
    owner = OffloadIngestOwner.find
    return render json: { error: "ingest owner not configured" }, status: :service_unavailable unless owner

    result = PresignRafUpload.call(owner: owner, filename: params[:filename], size: params[:size])

    if result.success?
      render json: result.data
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
end
