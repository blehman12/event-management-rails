#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 8: Database seeding"

cd "$APP_NAME"

cat > db/seeds.rb << 'SEEDS_EOF'
User.destroy_all
Venue.destroy_all
Event.destroy_all

admin = User.create!(
  first_name: 'Admin',
  last_name: 'User',
  email: 'admin@ptc.com',
  password: 'password123',
  phone: '503-555-0100',
  company: 'PTC',
  role: 'admin',
  invited_at: Time.current
)

venue = Venue.create!(
  name: 'Inland Chief Tugboat',
  address: 'Portland, OR',
  description: 'Historic tugboat venue',
  capacity: 60
)

event = Event.create!(
  name: 'PTC Windchill Community Meetup',
  description: 'Join fellow PTC Windchill users for networking.',
  event_date: 3.weeks.from_now,
  max_attendees: 60,
  rsvp_deadline: 2.weeks.from_now,
  venue: venue,
  creator: admin
)

5.times do |i|
  User.create!(
    first_name: "User#{i+1}",
    last_name: "Test",
    email: "user#{i+1}@example.com",
    password: 'password123',
    phone: "503-555-01#{10+i}",
    company: ['PTC', 'Boeing', 'Intel', 'Nike'].sample,
    invited_at: 2.days.ago,
    rsvp_status: ['pending', 'yes', 'maybe'].sample
  )
end

puts "Admin: admin@ptc.com / password123"
puts "Test: user1@example.com / password123"
SEEDS_EOF

rails db:drop 2>/dev/null || true
rails db:create
rails db:migrate
rails db:seed

echo "✓ Database setup completed!"