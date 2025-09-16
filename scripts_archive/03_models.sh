#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 3: Creating models"

cd "$APP_NAME"
rails generate model Venue name:string address:text description:text capacity:integer contact_info:text
rails generate model Event name:string description:text event_date:datetime start_time:time end_time:time max_attendees:integer rsvp_deadline:datetime venue_id:integer creator_id:integer

# Update migration versions
EVENT_MIGRATION=$(find db/migrate -name "*create_events.rb" | head -1)
VENUE_MIGRATION=$(find db/migrate -name "*create_venues.rb" | head -1)
sed -i 's/ActiveRecord::Migration\[[0-9.]*\]/ActiveRecord::Migration[7.1]/' "$EVENT_MIGRATION"
sed -i 's/ActiveRecord::Migration\[[0-9.]*\]/ActiveRecord::Migration[7.1]/' "$VENUE_MIGRATION"

# Create User model
cat > app/models/user.rb << 'EOF'
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { attendee: 0, admin: 1 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }

  validates :first_name, :last_name, :phone, :company, presence: true

  scope :invited, -> { where.not(invited_at: nil) }
  scope :registered, -> { where.not(registered_at: nil) }

  def full_name
    "#{first_name} #{last_name}"
  end
end
EOF

# FIXED: Create Venue model with proper validations
cat > app/models/venue.rb << 'EOF'
class Venue < ApplicationRecord
  has_many :events
  validates :name, :address, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }

  def full_address
    "#{name}, #{address}"
  end
end
EOF

# FIXED: Create Event model with proper methods
cat > app/models/event.rb << 'EOF'
class Event < ApplicationRecord
  belongs_to :venue
  belongs_to :creator, class_name: 'User'

  validates :name, :event_date, :rsvp_deadline, presence: true
  validates :max_attendees, presence: true, numericality: { greater_than: 0 }

  scope :upcoming, -> { where('event_date > ?', Time.current) }

  def attendees_count
    User.yes.count
  end

  def rsvp_open?
    Time.current <= rsvp_deadline
  end

  def spots_remaining
    max_attendees - attendees_count
  end

  def days_until_deadline
    return 0 if rsvp_deadline < Time.current
    ((rsvp_deadline - Time.current) / 1.day).ceil
  end
end
EOF

echo "✓ Models created successfully"
