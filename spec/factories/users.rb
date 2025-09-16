FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    sequence(:email) { |n| "user#{n}@example.com" }
    phone { "503-555-0123" }
    company { "Test Company" }
    password { "password123" }
    text_capable { true }
    role { :attendee }
    rsvp_status { :pending }

    trait :admin do
      role { :admin }
      first_name { "Admin" }
      last_name { "User" }
      email { "admin@ptc.com" }
      company { "PTC" }
    end

    trait :with_rsvp_yes do
      rsvp_status { :yes }
      registered_at { 1.week.ago }
    end

    trait :vendor do
      company { "Vendor Corp" }
    end
  end
end
