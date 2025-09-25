FactoryBot.define do
  factory :venue do
    name { Faker::Company.name + " Hall" }
    address { Faker::Address.full_address }
    description { Faker::Lorem.paragraph }
    capacity { rand(50..500) }
    contact_info { Faker::Internet.email }
  end
end
