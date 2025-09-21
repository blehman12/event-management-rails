# spec/rails_helper.rb
require 'spec_helper'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'

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
  
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :request
  
  # Include custom support modules
  config.include AuthenticationHelpers
  config.include FactoryHelpers
end

# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def login_as_admin
    user = create(:admin_user)
    sign_in user
    user
  end
  
  def login_as_user
    user = create(:user)
    sign_in user
    user
  end
end

# spec/support/factory_helpers.rb
module FactoryHelpers
  def build_stubbed_list(*args)
    FactoryBot.build_stubbed_list(*args)
  end
end

# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    company { Faker::Company.name }
    phone { Faker::PhoneNumber.phone_number }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'attendee' }
    text_capable { [true, false].sample }
    
    factory :admin_user do
      role { 'admin' }
      email { 'admin@test.com' }
    end
  end
end

# spec/factories/venues.rb
FactoryBot.define do
  factory :venue do
    name { Faker::Company.name + ' Conference Center' }
    address { Faker::Address.full_address }
    capacity { rand(50..500) }
    contact_info { Faker::PhoneNumber.phone_number }
  end
end

# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    name { Faker::Company.catch_phrase + ' Workshop' }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    event_date { 2.weeks.from_now.to_date }
    start_time { '09:00:00' }
    end_time { '17:00:00' }
    max_attendees { 100 }
    rsvp_deadline { 1.week.from_now }
    active { true }
    association :venue
    custom_questions { [] }
    
    factory :event_with_custom_questions do
      custom_questions { ['Any dietary restrictions?', 'T-shirt size?'] }
    end
    
    factory :past_event do
      event_date { 1.week.ago.to_date }
      rsvp_deadline { 2.weeks.ago }
    end
  end
end

# spec/factories/event_participants.rb
FactoryBot.define do
  factory :event_participant do
    association :user
    association :event
    role { 'attendee' }
    rsvp_status { 'pending' }
    rsvp_answers { {} }
    
    factory :confirmed_participant do
      rsvp_status { 'yes' }
    end
    
    factory :vendor_participant do
      role { 'vendor' }
      rsvp_status { 'yes' }
    end
    
    factory :organizer_participant do
      role { 'organizer' }
      rsvp_status { 'yes' }
    end
    
    factory :checked_in_participant do
      rsvp_status { 'yes' }
      checked_in_at { 1.hour.ago }
      check_in_method { 'qr_code' }
    end
  end
end

# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end
  
  describe 'associations' do
    it { should have_many(:event_participants) }
    it { should have_many(:events).through(:event_participants) }
  end
  
  describe 'enums' do
    it { should define_enum_for(:role).with_values(attendee: 0, admin: 1) }
  end
  
  describe '#admin?' do
    it 'returns true for admin users' do
      user = build(:admin_user)
      expect(user.admin?).to be true
    end
    
    it 'returns false for regular users' do
      user = build(:user)
      expect(user.admin?).to be false
    end
  end
  
  describe '#full_name' do
    it 'returns first and last name combined' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end
end

# spec/models/event_spec.rb
require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:event_date) }
  end
  
  describe 'associations' do
    it { should belong_to(:venue) }
    it { should have_many(:event_participants) }
    it { should have_many(:users).through(:event_participants) }
  end
  
  describe 'scopes' do
    let!(:upcoming_event) { create(:event, event_date: 1.week.from_now) }
    let!(:past_event) { create(:past_event) }
    
    describe '.upcoming' do
      it 'returns events in the future' do
        expect(Event.upcoming).to include(upcoming_event)
        expect(Event.upcoming).not_to include(past_event)
      end
    end
    
    describe '.active' do
      let!(:inactive_event) { create(:event, active: false) }
      
      it 'returns only active events' do
        expect(Event.active).to include(upcoming_event)
        expect(Event.active).not_to include(inactive_event)
      end
    end
  end
  
  describe '#rsvp_deadline_passed?' do
    it 'returns true when deadline has passed' do
      event = build(:event, rsvp_deadline: 1.day.ago)
      expect(event.rsvp_deadline_passed?).to be true
    end
    
    it 'returns false when deadline is in the future' do
      event = build(:event, rsvp_deadline: 1.day.from_now)
      expect(event.rsvp_deadline_passed?).to be false
    end
  end
  
  describe '#spots_remaining' do
    let(:event) { create(:event, max_attendees: 5) }
    
    it 'calculates remaining spots correctly' do
      create_list(:confirmed_participant, 2, event: event)
      expect(event.spots_remaining).to eq(3)
    end
  end
end

# spec/models/event_participant_spec.rb
require 'rails_helper'

RSpec.describe EventParticipant, type: :model do
  describe 'validations' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    
    it 'validates uniqueness of user per event' do
      create(:event_participant, user: user, event: event)
      duplicate = build(:event_participant, user: user, event: event)
      expect(duplicate).not_to be_valid
    end
  end
  
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:event) }
    it { should belong_to(:checked_in_by).optional }
  end
  
  describe 'enums' do
    it { should define_enum_for(:role).with_values(attendee: 0, vendor: 1, organizer: 2) }
    it { should define_enum_for(:rsvp_status).with_values(pending: 0, yes: 1, no: 2, maybe: 3) }
  end
  
  describe 'callbacks' do
    it 'generates QR code token after creation' do
      participant = create(:event_participant)
      expect(participant.qr_code_token).to be_present
    end
  end
  
  describe '#checked_in?' do
    it 'returns true when checked_in_at is present' do
      participant = build(:checked_in_participant)
      expect(participant.checked_in?).to be true
    end
    
    it 'returns false when checked_in_at is nil' do
      participant = build(:event_participant)
      expect(participant.checked_in?).to be false
    end
  end
  
  describe '#check_in!' do
    let(:participant) { create(:event_participant) }
    let(:admin) { create(:admin_user) }
    
    it 'updates check-in attributes' do
      participant.check_in!(method: :manual, checked_in_by: admin)
      
      expect(participant.checked_in_at).to be_present
      expect(participant.check_in_method).to eq('manual')
      expect(participant.checked_in_by).to eq(admin)
    end
  end
  
  describe '#rsvp_status_display' do
    it 'handles nil status gracefully' do
      participant = build(:event_participant, rsvp_status: nil)
      expect(participant.rsvp_status_display).to eq('Pending')
    end
    
    it 'humanizes valid statuses' do
      participant = build(:event_participant, rsvp_status: 'yes')
      expect(participant.rsvp_status_display).to eq('Yes')
    end
  end
  
  describe '#qr_code_data' do
    let(:participant) { create(:event_participant) }
    
    it 'generates proper QR code URL' do
      url = participant.qr_code_data
      expect(url).to include('/checkin/verify')
      expect(url).to include("token=#{participant.qr_code_token}")
      expect(url).to include("event=#{participant.event_id}")
    end
  end
end

# spec/controllers/admin/users_controller_spec.rb
require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:user) }
  
  before { sign_in admin }
  
  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to be_successful
    end
    
    it 'assigns all users' do
      users = create_list(:user, 3)
      get :index
      expect(assigns(:users)).to match_array(User.all)
    end
  end
  
  describe 'POST #create' do
    let(:valid_attributes) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        company: 'Test Corp',
        phone: '555-1234',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end
    
    it 'creates a new user with valid attributes' do
      expect {
        post :create, params: { user: valid_attributes }
      }.to change(User, :count).by(1)
    end
    
    it 'redirects to user show page' do
      post :create, params: { user: valid_attributes }
      expect(response).to redirect_to(admin_user_path(User.last))
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:user_to_delete) { create(:user) }
    
    it 'deletes the user' do
      expect {
        delete :destroy, params: { id: user_to_delete.id }
      }.to change(User, :count).by(-1)
    end
    
    it 'prevents self-deletion' do
      expect {
        delete :destroy, params: { id: admin.id }
      }.not_to change(User, :count)
    end
    
    it 'prevents deletion of last admin' do
      admin # Create the admin
      User.where.not(id: admin.id).destroy_all # Remove other users
      
      expect {
        delete :destroy, params: { id: admin.id }
      }.not_to change(User, :count)
    end
  end
end

# spec/controllers/rsvp_controller_spec.rb
require 'rails_helper'

RSpec.describe RsvpController, type: :controller do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:participant) { create(:event_participant, user: user, event: event) }
  
  before { sign_in user }
  
  describe 'PATCH #update' do
    it 'updates RSVP status' do
      patch :update, params: { event_id: event.id, rsvp_status: 'yes' }
      
      participant.reload
      expect(participant.rsvp_status).to eq('yes')
    end
    
    it 'redirects with success message' do
      patch :update, params: { event_id: event.id, rsvp_status: 'yes' }
      expect(flash[:notice]).to be_present
    end
    
    it 'prevents RSVP after deadline' do
      event.update(rsvp_deadline: 1.day.ago)
      
      patch :update, params: { event_id: event.id, rsvp_status: 'yes' }
      expect(flash[:alert]).to include('deadline')
    end
  end
end

# spec/controllers/checkin_controller_spec.rb
require 'rails_helper'

RSpec.describe CheckinController, type: :controller do
  let(:event) { create(:event) }
  let(:participant) { create(:confirmed_participant, event: event) }
  
  describe 'POST #verify' do
    context 'with valid QR code token' do
      it 'checks in the participant' do
        post :verify, params: { 
          token: participant.qr_code_token,
          event: event.id,
          participant: participant.id
        }
        
        participant.reload
        expect(participant.checked_in?).to be true
      end
      
      it 'redirects to success page' do
        post :verify, params: { 
          token: participant.qr_code_token,
          event: event.id,
          participant: participant.id
        }
        
        expect(response).to redirect_to(checkin_success_path(participant))
      end
    end
    
    context 'with invalid token' do
      it 'redirects with error' do
        post :verify, params: { 
          token: 'invalid_token',
          event: event.id,
          participant: participant.id
        }
        
        expect(flash[:alert]).to be_present
      end
    end
    
    context 'with manual entry' do
      it 'finds and checks in participant by email' do
        post :verify, params: {
          first_name: participant.user.first_name,
          last_name: participant.user.last_name,
          email: participant.user.email,
          event_id: event.id
        }
        
        participant.reload
        expect(participant.checked_in?).to be true
      end
    end
  end
end

# spec/mailers/invitation_mailer_spec.rb
require 'rails_helper'

RSpec.describe InvitationMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:mail) { InvitationMailer.event_invitation(user, event) }
  
  describe '#event_invitation' do
    it 'sends to the correct email' do
      expect(mail.to).to eq([user.email])
    end
    
    it 'includes event name in subject' do
      expect(mail.subject).to include(event.name)
    end
    
    it 'includes RSVP URL in body' do
      expect(mail.body.encoded).to include('rsvp')
      expect(mail.body.encoded).to include(event.id.to_s)
    end
    
    it 'includes event details' do
      expect(mail.body.encoded).to include(event.name)
      expect(mail.body.encoded).to include(event.venue.name)
    end
    
    it 'includes user name' do
      expect(mail.body.encoded).to include(user.first_name)
    end
  end
end

# spec/features/admin_user_management_spec.rb
require 'rails_helper'

RSpec.describe 'Admin User Management', type: :feature, js: true do
  let!(:admin) { create(:admin_user) }
  
  before do
    login_as admin
    visit admin_users_path
  end
  
  scenario 'Admin can create a new user' do
    click_link 'New User'
    
    fill_in 'First name', with: 'Jane'
    fill_in 'Last name', with: 'Smith'
    fill_in 'Email', with: 'jane@example.com'
    fill_in 'Company', with: 'Tech Corp'
    fill_in 'Phone', with: '555-0123'
    fill_in 'Password', with: 'password123'
    fill_in 'Password confirmation', with: 'password123'
    
    click_button 'Create User'
    
    expect(page).to have_content('User was successfully created')
    expect(page).to have_content('Jane Smith')
  end
  
  scenario 'Admin can edit user details' do
    user = create(:user, first_name: 'Bob')
    visit admin_users_path
    
    within("tr[data-user-id='#{user.id}']") do
      click_link 'Edit'
    end
    
    fill_in 'First name', with: 'Robert'
    click_button 'Update User'
    
    expect(page).to have_content('User was successfully updated')
    expect(page).to have_content('Robert')
  end
  
  scenario 'Admin can delete a user' do
    user = create(:user)
    visit admin_users_path
    
    within("tr[data-user-id='#{user.id}']") do
      click_button 'Delete User'
    end
    
    accept_confirm
    
    expect(page).to have_content('User was successfully deleted')
    expect(page).not_to have_content(user.email)
  end
end

# spec/features/rsvp_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'RSVP Workflow', type: :feature do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:participant) { create(:event_participant, user: user, event: event) }
  
  before { login_as user }
  
  scenario 'User can RSVP to an event' do
    visit event_rsvp_path(event)
    
    expect(page).to have_content(event.name)
    expect(page).to have_content(event.venue.name)
    
    click_button 'Yes'
    
    expect(page).to have_content('RSVP updated successfully')
    
    participant.reload
    expect(participant.rsvp_status).to eq('yes')
  end
  
  scenario 'User sees deadline warning' do
    event.update(rsvp_deadline: 1.day.from_now)
    visit event_rsvp_path(event)
    
    expect(page).to have_content('1 day left to RSVP')
  end
  
  scenario 'User cannot RSVP after deadline' do
    event.update(rsvp_deadline: 1.day.ago)
    visit event_rsvp_path(event)
    
    expect(page).to have_content('RSVP deadline has passed')
    expect(page).not_to have_button('Yes')
  end
end

# spec/features/checkin_process_spec.rb
require 'rails_helper'

RSpec.describe 'Check-in Process', type: :feature do
  let(:event) { create(:event) }
  let(:participant) { create(:confirmed_participant, event: event) }
  
  scenario 'Manual check-in works' do
    visit checkin_scan_path
    
    fill_in 'First Name', with: participant.user.first_name
    fill_in 'Last Name', with: participant.user.last_name
    fill_in 'Email Address', with: participant.user.email
    select event.name, from: 'Event'
    
    click_button 'Check In Manually'
    
    expect(page).to have_content('Check-in Successful')
    expect(page).to have_content(participant.user.first_name)
    
    participant.reload
    expect(participant.checked_in?).to be true
  end
end