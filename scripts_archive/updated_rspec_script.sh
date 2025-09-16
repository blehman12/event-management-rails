#!/bin/bash

# RSpec Test Suite Generator for PTC Windchill Event App (Updated)
# Run this script from the application root directory

set -e

APP_NAME="${1:-ev1}"
echo "Setting up RSpec test suite for: $APP_NAME"

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
  echo "Error: No Gemfile found. Please run this script from the Rails application root directory."
  echo "Usage: ./scripts_archive/rspec_test_suite.sh (from within the ev1 directory)"
  exit 1
fi

# 1. Add RSpec gems to Gemfile
echo "Adding RSpec gems to Gemfile..."
cat >> Gemfile << 'GEMS_EOF'

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'database_cleaner-active_record'
end
GEMS_EOF

# Install gems
echo "Installing gems..."
bundle install

# 2. Initialize RSpec
echo "Initializing RSpec..."
rails generate rspec:install

# 3. Configure RSpec
echo "Configuring RSpec..."
cat > spec/rails_helper.rb << 'RAILS_HELPER_EOF'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'

# Configure Capybara
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :request
  
  # Database cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
RAILS_HELPER_EOF

# 4. Create spec directories
echo "Creating spec directory structure..."
mkdir -p spec/{models,controllers,features,factories,support}

# 5. Create factories based on current models
echo "Creating factories..."
cat > spec/factories/users.rb << 'USER_FACTORY_EOF'
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
USER_FACTORY_EOF

cat > spec/factories/venues.rb << 'VENUE_FACTORY_EOF'
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
VENUE_FACTORY_EOF

cat > spec/factories/events.rb << 'EVENT_FACTORY_EOF'
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
EVENT_FACTORY_EOF

# Only create EventParticipant factory if the model exists
if rails runner "puts defined?(EventParticipant)" 2>/dev/null | grep -q "constant"; then
  cat > spec/factories/event_participants.rb << 'EVENT_PARTICIPANT_FACTORY_EOF'
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
EVENT_PARTICIPANT_FACTORY_EOF
fi

# 6. Create basic model specs
echo "Creating model specs..."
cat > spec/models/user_spec.rb << 'USER_SPEC_EOF'
require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:phone) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(attendee: 0, admin: 1) }
    it { is_expected.to define_enum_for(:rsvp_status).with_values(pending: 0, yes: 1, no: 2, maybe: 3) }
  end

  describe '#full_name' do
    it 'returns the full name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe 'admin functionality' do
    let(:admin) { create(:user, :admin) }
    let(:regular_user) { create(:user) }

    it 'identifies admin users correctly' do
      expect(admin.admin?).to be true
      expect(regular_user.admin?).to be false
    end
  end
end
USER_SPEC_EOF

cat > spec/models/event_spec.rb << 'EVENT_SPEC_EOF'
require 'rails_helper'

RSpec.describe Event, type: :model do
  subject { build(:event) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:event_date) }
    it { is_expected.to validate_presence_of(:rsvp_deadline) }
    it { is_expected.to validate_presence_of(:max_attendees) }
    it { is_expected.to validate_numericality_of(:max_attendees).is_greater_than(0) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:venue) }
    it { is_expected.to belong_to(:creator).class_name('User') }
  end

  describe 'scopes' do
    let!(:past_event) { create(:event, :past) }
    let!(:upcoming_event) { create(:event, :upcoming) }

    describe '.upcoming' do
      it 'returns events in the future' do
        expect(Event.upcoming).to include(upcoming_event)
        expect(Event.upcoming).not_to include(past_event)
      end
    end
  end

  describe '#rsvp_open?' do
    it 'returns true when deadline is in the future' do
      event = build(:event, rsvp_deadline: 1.day.from_now)
      expect(event.rsvp_open?).to be true
    end

    it 'returns false when deadline has passed' do
      event = build(:event, rsvp_deadline: 1.day.ago)
      expect(event.rsvp_open?).to be false
    end
  end
end
EVENT_SPEC_EOF

cat > spec/models/venue_spec.rb << 'VENUE_SPEC_EOF'
require 'rails_helper'

RSpec.describe Venue, type: :model do
  subject { build(:venue) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_presence_of(:capacity) }
    it { is_expected.to validate_numericality_of(:capacity).is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:events).dependent(:destroy) }
  end

  describe '#full_address' do
    it 'returns name and address combined' do
      venue = build(:venue, name: 'Test Venue', address: '123 Main St')
      expect(venue.full_address).to eq('Test Venue, 123 Main St')
    end
  end
end
VENUE_SPEC_EOF

# 7. Create basic controller specs
echo "Creating controller specs..."
cat > spec/controllers/dashboard_controller_spec.rb << 'DASHBOARD_CONTROLLER_SPEC_EOF'
require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end

  context 'when user is not signed in' do
    before { sign_out user }

    it 'redirects to sign in page' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
DASHBOARD_CONTROLLER_SPEC_EOF

# 8. Create support files
echo "Creating support files..."
cat > spec/support/database_cleaner.rb << 'DB_CLEANER_EOF'
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
DB_CLEANER_EOF

cat > spec/support/capybara.rb << 'CAPYBARA_EOF'
Capybara.configure do |config|
  config.default_max_wait_time = 5
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_chrome_headless
end

# Configure Chrome for headless testing
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1200,800')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
DB_CLEANER_EOF

# 9. Create test database and run initial test
echo "Setting up test database..."
RAILS_ENV=test rails db:create db:migrate

echo ""
echo "SUCCESS! RSpec test suite setup completed!"
echo ""
echo "NEW TESTING FEATURES:"
echo "✓ RSpec testing framework configured"
echo "✓ FactoryBot for test data generation"
echo "✓ Shoulda matchers for concise testing"
echo "✓ Capybara for integration testing"
echo "✓ Database cleaner for isolated tests"
echo "✓ Basic model and controller specs created"
echo ""
echo "USAGE:"
echo "• Run all tests: bundle exec rspec"
echo "• Run specific tests: bundle exec rspec spec/models"
echo "• Run with documentation: bundle exec rspec --format documentation"
echo ""
echo "Test files created in spec/ directory:"
echo "• spec/models/ - Model unit tests"
echo "• spec/controllers/ - Controller tests"
echo "• spec/factories/ - Test data factories"
echo "• spec/support/ - Test configuration"
echo ""
echo "Ready to run: bundle exec rspec"