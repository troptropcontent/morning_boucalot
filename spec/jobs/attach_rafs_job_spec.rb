require "rails_helper"

RSpec.describe AttachRafsJob do
  it "tries to attach every object in the bucket" do
    bucket = instance_double(RafBucket)
    allow(bucket).to receive(:each_object).and_yield("rafs/1/5/A.RAF", 5, "e1").and_yield("rafs/1/6/B.RAF", 6, "e2")
    allow(AttachRafFromBucket).to receive(:call)

    described_class.perform_now(bucket: bucket)

    expect(AttachRafFromBucket).to have_received(:call).with(key: "rafs/1/5/A.RAF", size: 5, etag: "e1")
    expect(AttachRafFromBucket).to have_received(:call).with(key: "rafs/1/6/B.RAF", size: 6, etag: "e2")
  end

  it "keeps going when one object raises, then fails the job so it isn't silent" do
    bucket = instance_double(RafBucket)
    allow(bucket).to receive(:each_object).and_yield("rafs/1/5/A.RAF", 5, "e1").and_yield("rafs/1/6/B.RAF", 6, "e2")
    allow(AttachRafFromBucket).to receive(:call).with(hash_including(key: "rafs/1/5/A.RAF")).and_raise(ActiveRecord::RecordNotUnique)
    allow(AttachRafFromBucket).to receive(:call).with(hash_including(key: "rafs/1/6/B.RAF"))

    expect { described_class.perform_now(bucket: bucket) }
      .to raise_error(AttachRafsJob::PartialFailure, %r{1 RAF\(s\) failed to attach: rafs/1/5/A.RAF})

    expect(AttachRafFromBucket).to have_received(:call).with(hash_including(key: "rafs/1/6/B.RAF"))
  end
end
