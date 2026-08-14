FactoryBot.define do
  factory :user do
    email_address { Faker::Internet.unique.email }
    password { "password123" }

    trait :guest do
      role { :guest }
      password { nil }
    end
  end
end
