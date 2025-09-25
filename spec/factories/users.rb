FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'attendee' }
    company { Faker::Company.name }
    phone { Faker::PhoneNumber.phone_number }

    trait :admin do
      role { 'admin' }
    end

    trait :vendor do
      role { 'vendor' }
    end
  end
end
