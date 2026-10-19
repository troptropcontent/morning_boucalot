require "rails_helper"

RSpec.describe AttachRafFromBucket do
  let(:photo) { FactoryBot.create(:photo) }
  let(:stem) { File.basename(photo.file.blob.filename.to_s, ".*") }
  let(:key) { "rafs/#{photo.user_id}/50/#{stem}.RAF" }
  let(:etag) { "d41d8cd98f00b204e9800998ecf8427e" }

  def call(key: self.key, etag: self.etag)
    described_class.call(key: key, size: 50, etag: etag)
  end

  it "attaches a blob around the existing key, with the ETag as checksum" do
    call

    blob = photo.reload.raw_file.blob
    expect(photo.raw_file).to be_attached
    expect(blob.key).to eq(key)
    expect(blob.filename.to_s).to eq("#{stem}.RAF")
    expect(blob.byte_size).to eq(50)
    expect(blob.checksum).to eq("1B2M2Y8AsgTpgAmY7PhCfg==")
  end

  it "does nothing when the key is already attached" do
    call
    expect { call }.not_to change(ActiveStorage::Blob, :count)
  end

  it "does nothing when no photo matches yet" do
    expect(call(key: "rafs/#{photo.user_id}/50/OTHER.RAF").data).to be_nil
    expect(photo.reload.raw_file).not_to be_attached
  end

  it "ignores another owner's photo with the same stem" do
    expect(call(key: "rafs/#{photo.user_id + 1}/50/#{stem}.RAF").data).to be_nil
  end

  it "skips photos that already have a raw_file" do
    call
    expect(call(key: "rafs/#{photo.user_id}/60/#{stem}.RAF").data).to be_nil
  end

  it "skips multipart ETags, which aren't an MD5" do
    expect(call(etag: "abc-2").data).to be_nil
  end

  it "leaves no blob behind when the attach fails, so the next run can retry" do
    key # create the photo (and its file) before attach is stubbed
    allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_return(false)

    expect { call }.not_to change(ActiveStorage::Blob, :count)
    expect(ActiveStorage::Blob.exists?(key: key)).to be false
  end
end
