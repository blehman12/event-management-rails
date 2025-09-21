FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Test Event #{n}" }
    description { "A test event description" }
    event_date { 2.weeks.from_now.to_date }
    start_time { "09:00:00" }
    end_time { "17:00:00" }
    max_attendees { 100 }
    rsvp_deadline { 1.week.from_now }
    association :venue
    association :creator, factory: :user
    custom_questions { [] }
    
    trait :upcoming do
      event_date { 1.month.from_now.to_date }
    end
    
    trait :past do
      event_date { 1.week.ago.to_date }
      rsvp_deadline { 2.weeks.ago }
    end
  end
end