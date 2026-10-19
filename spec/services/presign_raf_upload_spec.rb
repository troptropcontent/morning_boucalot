require "rails_helper"

RSpec.describe PresignRafUpload do
  let(:user) { FactoryBot.create(:user) }
  let(:bucket) { instance_double(RafBucket, exists?: false, presigned_put_url: "https://s3/put") }

  def call(filename: "DSCF1234.RAF", size: 50_000_000)
    described_class.call(owner: user, filename: filename, size: size, bucket: bucket)
  end

  it "returns a presigned URL and the headers to send" do
    result = call

    expect(result.data).to eq(already_uploaded: false, url: "https://s3/put", headers: { "Content-Type" => "application/octet-stream" })
    expect(bucket).to have_received(:presigned_put_url).with("rafs/#{user.id}/50000000/DSCF1234.RAF")
  end

  it "reports a RAF already in the bucket without presigning" do
    allow(bucket).to receive(:exists?).and_return(true)

    expect(call.data).to eq(already_uploaded: true)
    expect(bucket).not_to have_received(:presigned_put_url)
  end

  it "accepts a lowercase extension" do
    expect(call(filename: "dscf1234.raf")).to be_success
  end

  [ "DSCF1234.JPG", "../x.RAF", "a/b.RAF", "", nil ].each do |filename|
    it "rejects filename #{filename.inspect}" do
      expect(call(filename: filename).errors).to eq([ "filename must be a .raf file" ])
    end
  end

  [ "0", "-5", "abc", nil ].each do |size|
    it "rejects size #{size.inspect}" do
      expect(call(size: size).errors).to eq([ "size must be a positive integer" ])
    end
  end
end
