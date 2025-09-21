# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    sequence(:email) { |n| "user#{n}@example.com" }
    phone { "503-555-0123" }
    company { "Test Company" }
    password { "password123" }
    password_confirmation { "password123" }
    text_capable { true }
    role { :attendee }
    invited_at { nil }
    registered_at { nil }
    
    trait :admin do
      role { :admin }
      first_name { "Admin" }
      last_name { "User" }
      email { "admin@ptc.com" }
      company { "PTC" }
    end
    
    trait :registered do
      registered_at { 1.week.ago }
      invited_at { 2.weeks.ago }
    end
    
    trait :vendor_user do
      company { "Vendor Corp" }
      first_name { "Vendor" }
      last_name { "Representative" }
    end
    
    trait :ptc_employee do
      company { "PTC" }
      sequence(:email) { |n| "employee#{n}@ptc.com" }
    end
    
    # Factory for creating users with specific attributes
    factory :admin_user, traits: [:admin]
    factory :vendor_user_account, traits: [:vendor_user]
    factory :registered_user, traits: [:registered]
  end
end