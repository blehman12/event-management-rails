FactoryBot.define do
  factory :venue do
    name { "Portland Tech Center" }
    address { "9205 SW Gemini Dr, Beaverton, OR 97008" }
    description { "Modern conference facility" }
    capacity { 150 }
    contact_info { "events@portlandtech.com" }

    trait :small do
      name { "Small Meeting Room" }
      capacity { 20 }
    end

    trait :large do
      name { "Convention Center" }
      capacity { 500 }
    end
  end
end
