FactoryBot.define do
  factory :venue do
    sequence(:name) { |n| "Test Venue #{n}" }
    address { "123 Test Street, Portland, OR 97201" }
    capacity { 150 }
    contact_info { "503-555-0199" }
  end
end