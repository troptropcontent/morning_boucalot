FactoryBot.define do
  factory :photo do
    association :user
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    taken_at { Faker::Time.backward(days: 365) }
    camera_model { "Canon EOS R5" }
    focal_length { 50.0 }
    aperture { 1.8 }
    iso { 100 }
    shutter_speed { "1/250" }
    width { 4000 }
    height { 3000 }
    file_size { 5_000_000 }

    after(:build) do |photo|
      photo.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
