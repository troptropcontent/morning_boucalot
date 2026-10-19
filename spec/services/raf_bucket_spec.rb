require "rails_helper"

RSpec.describe RafBucket do
  let(:object) { double("S3 object") }
  let(:s3_bucket) { double("S3 bucket") }
  let(:bucket) { described_class.new(bucket: s3_bucket) }
  let(:user) { FactoryBot.build_stubbed(:user) }

  it "builds keys under the owner's prefix, segmented by size" do
    expect(described_class.key_for(owner: user, filename: "DSCF1.RAF", size: 50)).to eq("rafs/#{user.id}/50/DSCF1.RAF")
  end

  it "presigns a PUT with a content type and TTL" do
    allow(s3_bucket).to receive(:object).with("k").and_return(object)
    expect(object).to receive(:presigned_url).with(:put, expires_in: 1800, content_type: "application/octet-stream").and_return("https://s3/put")

    expect(bucket.presigned_put_url("k")).to eq("https://s3/put")
  end

  it "checks existence" do
    allow(s3_bucket).to receive(:object).with("k").and_return(object)
    allow(object).to receive(:exists?).and_return(true)

    expect(bucket.exists?("k")).to be true
  end

  it "yields key, size and unquoted etag for each object" do
    summary = double("summary", key: "rafs/1/5/A.RAF", size: 5, etag: '"abc"')
    allow(s3_bucket).to receive(:objects).with(prefix: "rafs/").and_return([ summary ])

    expect { |b| bucket.each_object(&b) }.to yield_with_args("rafs/1/5/A.RAF", 5, "abc")
  end

  it "defaults to the Active Storage bucket" do
    service = double(bucket: s3_bucket)
    allow(ActiveStorage::Blob).to receive(:service).and_return(service)

    expect(described_class.new.instance_variable_get(:@bucket)).to eq(s3_bucket)
  end
end
