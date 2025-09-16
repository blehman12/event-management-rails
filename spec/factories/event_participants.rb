FactoryBot.define do
  factory :event_participant do
    association :user
    association :event
    role { :attendee }
    rsvp_status { :pending }
    invited_at { 1.week.ago }

    trait :organizer do
      role { :organizer }
      rsvp_status { :yes }
      responded_at { 1.week.ago }
    end

    trait :vendor do
      role { :vendor }
    end

    trait :confirmed do
      rsvp_status { :yes }
      responded_at { 3.days.ago }
    end

    trait :declined do
      rsvp_status { :no }
      responded_at { 2.days.ago }
    end
  end
end
