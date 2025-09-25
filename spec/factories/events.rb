FactoryBot.define do
  factory :event do
    name { Faker::Lorem.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    event_date { 2.weeks.from_now }
    rsvp_deadline { 1.week.from_now }
    start_time { '09:00' }
    end_time { '17:00' }
    max_attendees { rand(20..200) }
    custom_questions { [] }
    
    association :venue
    association :creator, factory: :user

    trait :upcoming do
      event_date { rand(1..4).weeks.from_now }
    end

    trait :past do
      event_date { rand(1..4).weeks.ago }
      rsvp_deadline { rand(2..5).weeks.ago }
    end

    trait :with_questions do
      custom_questions { ['Any dietary restrictions?', 'T-shirt size?', 'Will you need parking?'] }
    end
  end
end
