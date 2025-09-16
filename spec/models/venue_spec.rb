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
