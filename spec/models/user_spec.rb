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
