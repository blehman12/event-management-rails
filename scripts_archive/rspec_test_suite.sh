#!/bin/bash

# RSpec Test Suite Generator for PTC Windchill Event App
# Run this script after the application is built to create comprehensive tests

set -e

APP_NAME="${1:-ev1}"
echo "Setting up RSpec test suite for: $APP_NAME"

cd "$APP_NAME"

# 1. Add RSpec gems to Gemfile
echo "Adding RSpec gems to Gemfile..."
cat >> Gemfile << 'GEMS_EOF'

group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'database_cleaner-active_record'
end
GEMS_EOF

# Install gems
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

# 5. Create factories
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

# 6. Create model specs
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

  describe 'associations' do
    it { is_expected.to have_many(:event_participants).dependent(:destroy) }
    it { is_expected.to have_many(:events).through(:event_participants) }
    it { is_expected.to have_many(:created_events).class_name('Event') }
  end

  describe '#full_name' do
    it 'returns the full name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe 'scopes' do
    let!(:invited_user) { create(:user, invited_at: 1.week.ago) }
    let!(:registered_user) { create(:user, registered_at: 1.week.ago) }
    let!(:uninvited_user) { create(:user, invited_at: nil) }

    describe '.invited' do
      it 'returns users with invited_at set' do
        expect(User.invited).to include(invited_user)
        expect(User.invited).not_to include(uninvited_user)
      end
    end

    describe '.registered' do
      it 'returns users with registered_at set' do
        expect(User.registered).to include(registered_user)
        expect(User.registered).not_to include(uninvited_user)
      end
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
    it { is_expected.to have_many(:event_participants).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:event_participants) }
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

    describe '.past' do
      it 'returns events in the past' do
        expect(Event.past).to include(past_event)
        expect(Event.past).not_to include(upcoming_event)
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

  describe '#attendees_count' do
    let(:event) { create(:event) }
    
    before do
      create(:event_participant, :confirmed, event: event)
      create(:event_participant, :confirmed, event: event)
      create(:event_participant, :declined, event: event)
    end

    it 'returns the count of confirmed attendees' do
      expect(event.attendees_count).to eq(2)
    end
  end

  describe '#spots_remaining' do
    let(:event) { create(:event, max_attendees: 10) }
    
    before do
      create(:event_participant, :confirmed, event: event)
      create(:event_participant, :confirmed, event: event)
    end

    it 'returns remaining spots' do
      expect(event.spots_remaining).to eq(8)
    end
  end

  describe 'custom validations' do
    it 'validates rsvp_deadline is before event_date' do
      event = build(:event, event_date: 1.week.from_now, rsvp_deadline: 2.weeks.from_now)
      expect(event).not_to be_valid
      expect(event.errors[:rsvp_deadline]).to include('must be before event date')
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

  describe '#events_count' do
    let(:venue) { create(:venue) }
    
    before do
      create(:event, venue: venue)
      create(:event, venue: venue)
    end

    it 'returns the count of associated events' do
      expect(venue.events_count).to eq(2)
    end
  end

  describe '#upcoming_events' do
    let(:venue) { create(:venue) }
    let!(:past_event) { create(:event, :past, venue: venue) }
    let!(:upcoming_event) { create(:event, :upcoming, venue: venue) }

    it 'returns only upcoming events' do
      expect(venue.upcoming_events).to include(upcoming_event)
      expect(venue.upcoming_events).not_to include(past_event)
    end
  end
end
VENUE_SPEC_EOF

cat > spec/models/event_participant_spec.rb << 'EVENT_PARTICIPANT_SPEC_EOF'
require 'rails_helper'

RSpec.describe EventParticipant, type: :model do
  subject { build(:event_participant) }

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:event_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:event) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(attendee: 0, vendor: 1, organizer: 2) }
    it { is_expected.to define_enum_for(:rsvp_status).with_values(pending: 0, yes: 1, no: 2, maybe: 3) }
  end

  describe 'scopes' do
    let(:event) { create(:event) }
    let!(:vendor) { create(:event_participant, :vendor, event: event) }
    let!(:attendee) { create(:event_participant, event: event) }
    let!(:organizer) { create(:event_participant, :organizer, event: event) }
    let!(:confirmed) { create(:event_participant, :confirmed, event: event) }

    describe '.vendors' do
      it 'returns vendor participants' do
        expect(EventParticipant.vendors).to include(vendor)
        expect(EventParticipant.vendors).not_to include(attendee)
      end
    end

    describe '.organizers' do
      it 'returns organizer participants' do
        expect(EventParticipant.organizers).to include(organizer)
        expect(EventParticipant.organizers).not_to include(attendee)
      end
    end

    describe '.confirmed' do
      it 'returns confirmed participants' do
        expect(EventParticipant.confirmed).to include(confirmed)
        expect(EventParticipant.confirmed).to include(organizer) # organizer trait sets yes
      end
    end
  end

  describe '#respond_to_rsvp!' do
    let(:participant) { create(:event_participant) }

    it 'updates rsvp_status and responded_at' do
      expect {
        participant.respond_to_rsvp!('yes')
      }.to change { participant.rsvp_status }.to('yes')
       .and change { participant.responded_at }.from(nil)
    end
  end
end
EVENT_PARTICIPANT_SPEC_EOF

# 7. Create controller specs
echo "Creating controller specs..."
cat > spec/controllers/dashboard_controller_spec.rb << 'DASHBOARD_CONTROLLER_SPEC_EOF'
require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:event) { create(:event, :upcoming) }
    let!(:participant) { create(:event_participant, user: user, event: event, rsvp_status: :yes) }

    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @current_event' do
      get :index
      expect(assigns(:current_event)).to eq(event)
    end

    it 'assigns user RSVP status' do
      get :index
      expect(assigns(:user_rsvp_status)).to eq('yes')
    end

    it 'checks if deadline has passed' do
      get :index
      expect(assigns(:deadline_passed)).to be_falsey
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

cat > spec/controllers/admin/dashboard_controller_spec.rb << 'ADMIN_DASHBOARD_SPEC_EOF'
require 'rails_helper'

RSpec.describe Admin::DashboardController, type: :controller do
  describe 'GET #index' do
    context 'when user is admin' do
      let(:admin) { create(:user, :admin) }
      
      before do
        sign_in admin
      end

      it 'returns a success response' do
        get :index
        expect(response).to be_successful
      end

      it 'renders the dashboard template' do
        get :index
        expect(response).to render_template(:index)
      end
    end

    context 'when user is not admin' do
      let(:user) { create(:user) }
      
      before do
        sign_in user
      end

      it 'redirects to root path' do
        get :index
        expect(response).to redirect_to(root_path)
      end

      it 'sets an alert message' do
        get :index
        expect(flash[:alert]).to eq('Access denied. Admin privileges required.')
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
ADMIN_DASHBOARD_SPEC_EOF

cat > spec/controllers/rsvp_controller_spec.rb << 'RSVP_CONTROLLER_SPEC_EOF'
require 'rails_helper'

RSpec.describe RsvpController, type: :controller do
  let(:user) { create(:user) }
  let(:event) { create(:event, :upcoming) }
  let!(:participant) { create(:event_participant, user: user, event: event) }
  
  before do
    sign_in user
  end

  describe 'PATCH #update' do
    context 'when RSVP is open' do
      it 'updates user RSVP status' do
        patch :update, params: { status: 'yes', event_id: event.id }
        
        participant.reload
        expect(participant.rsvp_status).to eq('yes')
        expect(participant.responded_at).to be_present
      end

      it 'redirects to dashboard with success message' do
        patch :update, params: { status: 'yes', event_id: event.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('RSVP updated to Yes')
      end
    end

    context 'when RSVP deadline has passed' do
      let(:event) { create(:event, :rsvp_closed) }

      it 'does not update RSVP status' do
        original_status = participant.rsvp_status
        
        patch :update, params: { status: 'yes', event_id: event.id }
        
        participant.reload
        expect(participant.rsvp_status).to eq(original_status)
      end

      it 'redirects with error message' do
        patch :update, params: { status: 'yes', event_id: event.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You are not registered for this event')
      end
    end
  end
end
RSVP_CONTROLLER_SPEC_EOF

# 8. Create feature specs (integration tests)
echo "Creating feature specs..."
cat > spec/features/user_authentication_spec.rb << 'AUTH_FEATURE_EOF'
require 'rails_helper'

RSpec.feature "User Authentication", type: :feature do
  scenario "User signs up successfully" do
    visit new_user_registration_path
    
    fill_in "First name", with: "John"
    fill_in "Last name", with: "Doe"
    fill_in "Email", with: "john@example.com"
    fill_in "Phone", with: "503-555-0123"
    fill_in "Company", with: "Test Company"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    
    click_button "Sign up"
    
    expect(page).to have_content("Welcome! You have signed up successfully")
    expect(current_path).to eq(root_path)
  end

  scenario "User signs in and out" do
    user = create(:user, email: "test@example.com", password: "password123")
    
    visit new_user_session_path
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
    
    expect(page).to have_content("Hello, #{user.full_name}")
    
    click_button "Sign Out"
    expect(current_path).to eq(root_path)
    expect(page).not_to have_content("Hello, #{user.full_name}")
  end
end
AUTH_FEATURE_EOF

cat > spec/features/event_rsvp_spec.rb << 'RSVP_FEATURE_EOF'
require 'rails_helper'

RSpec.feature "Event RSVP", type: :feature do
  let(:user) { create(:user) }
  let(:event) { create(:event, :upcoming) }
  
  before do
    create(:event_participant, user: user, event: event)
    sign_in user
  end

  scenario "User can RSVP to an event", js: true do
    visit root_path
    
    expect(page).to have_content(event.name)
    expect(page).to have_content("Pending")
    
    click_button "Yes"
    
    expect(page).to have_content("RSVP updated")
    expect(page).to have_button("Yes", class: "btn-success")
  end

  scenario "User can change their RSVP", js: true do
    visit root_path
    
    click_button "Yes"
    expect(page).to have_button("Yes", class: "btn-success")
    
    click_button "Maybe"
    expect(page).to have_button("Maybe", class: "btn-warning")
  end

  scenario "User cannot RSVP after deadline" do
    closed_event = create(:event, :rsvp_closed)
    create(:event_participant, user: user, event: closed_event)
    
    visit root_path
    
    expect(page).to have_content("RSVP deadline has passed")
    expect(page).not_to have_button("Yes")
  end
end
RSVP_FEATURE_EOF

cat > spec/features/admin_functionality_spec.rb << 'ADMIN_FEATURE_EOF'
require 'rails_helper'

RSpec.feature "Admin Functionality", type: :feature do
  let(:admin) { create(:user, :admin) }
  
  before do
    sign_in admin
  end

  scenario "Admin can access admin dashboard" do
    visit admin_root_path
    
    expect(page).to have_content("Admin Dashboard")
    expect(page).to have_link("Events")
    expect(page).to have_link("Venues")
    expect(page).to have_link("Users")
  end

  scenario "Admin can create a new event" do
    venue = create(:venue)
    
    visit admin_events_path
    click_link "New Event"
    
    fill_in "Name", with: "Test Event"
    fill_in "Description", with: "A test event"
    select venue.name, from: "Venue"
    fill_in "Max attendees", with: "50"
    fill_in "Event date", with: 2.weeks.from_now.strftime("%Y-%m-%dT%H:%M")
    fill_in "RSVP deadline", with: 1.week.from_now.strftime("%Y-%m-%dT%H:%M")
    
    click_button "Create Event"
    
    expect(page).to have_content("Event was successfully created")
    expect(page).to have_content("Test Event")
  end

  scenario "Admin can manage users" do
    user = create(:user, first_name: "John", last_name: "Doe")
    
    visit admin_users_path
    
    expect(page).to have_content("John Doe")
    
    click_link "Edit"
    fill_in "First name", with: "Jane"
    click_button "Update User"
    
    expect(page).to have_content("User was successfully updated")
    expect(page).to have_content("Jane Doe")
  end

  scenario "Regular user cannot access admin area" do
    sign_out admin
    regular_user = create(:user)
    sign_in regular_user
    
    visit admin_root_path
    
    expect(current_path).to eq(root_path)
    expect(page).to have_content("Access denied")
  end
end
ADMIN_FEATURE_EOF

# 9. Create support files
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
CAPYBARA_EOF

# 10. Create test runner script
echo "Creating test runner script..."
cat > spec/support/test_runner.rb << 'TEST_RUNNER_EOF'
# Test Runner Helper
module TestRunner
  def self.run_all_tests
    puts "Running complete test suite..."
    puts "=" * 50
    
    # Run model tests
    puts "Running model tests..."
    system("bundle exec rspec spec/models --format documentation")
    
    # Run controller tests
    puts "\nRunning controller tests..."
    system("bundle exec rspec spec/controllers --format documentation")
    
    # Run feature tests
    puts "\nRunning feature tests..."
    system("bundle exec rspec spec/features --format documentation")
    
    puts "\nTest suite complete!"
  end
  
  def self.run_quick_tests
    puts "Running quick test suite (models only)..."
    system("bundle exec rspec spec/models --format progress")
  end
end
TEST_RUNNER_EOF

# 11. Create comprehensive test rake task
echo "Creating rake task for tests..."
cat > lib/tasks/test_suite.rake << 'RAKE_TASK_EOF'
namespace :test_suite do
  desc "Run comprehensive test suite with detailed output"
  task comprehensive: :environment do
    puts "Starting comprehensive test suite..."
    puts "App: #{Rails.application.class.module_parent_name}"
    puts "Environment: #{Rails.env}"
    puts "=" * 60
    
    # Check test database
    puts "Preparing test database..."
    Rake::Task['db:test:prepare'].invoke
    
    # Run tests by category
    test_categories = [
      { name: "Model Tests", path: "spec/models" },
      { name: "Controller Tests", path: "spec/controllers" },
      { name: "Feature Tests", path: "spec/features" }
    ]
    
    test_categories.each do |category|
      puts "\n" + "=" * 40
      puts