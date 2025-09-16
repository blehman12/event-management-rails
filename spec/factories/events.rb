FactoryBot.define do
  factory :event do
    name { "PTC Windchill Community Meetup" }
    description { "Join fellow PTC Windchill users for networking" }
    event_date { 3.weeks.from_now }
    start_time { Time.parse('6:00 PM') }
    end_time { Time.parse('9:00 PM') }
    max_attendees { 60 }
    rsvp_deadline { 2.weeks.from_now }
    association :venue
    association :creator, factory: [:user, :admin]

    trait :past do
      event_date { 1.month.ago }
      rsvp_deadline { 6.weeks.ago }
    end

    trait :upcoming do
      event_date { 2.weeks.from_now }
      rsvp_deadline { 1.week.from_now }
    end

    trait :rsvp_closed do
      rsvp_deadline { 1.day.ago }
    end
  end
end
