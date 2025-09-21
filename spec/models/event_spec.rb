describe 'validations' do
  subject { build(:event) }
  
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:event_date) }
  it { is_expected.to validate_presence_of(:rsvp_deadline) }
  it { is_expected.to validate_presence_of(:max_attendees) }
  it { is_expected.to validate_numericality_of(:max_attendees).is_greater_than(0) }
end

describe 'associations' do
  subject { build(:event) }  # Add this line
  
  it { is_expected.to belong_to(:venue) }
  it { is_expected.to belong_to(:creator).class_name('User') }
  it { is_expected.to have_many(:event_participants) }
  it { is_expected.to have_many(:users).through(:event_participants) }
end