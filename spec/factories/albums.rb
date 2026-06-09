FactoryBot.define do
  factory :album do
    association :user
    title { Faker::Lorem.words(number: 3).join(" ").capitalize }
    description { Faker::Lorem.sentence }
  end
end
