FactoryBot.define do
  factory :album_photo do
    association :album
    association :photo
    position { 0 }
  end
end
