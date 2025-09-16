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
        puts "Past event date: #{past_event.event_date}"
        puts "Upcoming event date: #{upcoming_event.event_date}"
        puts "Current time: #{Time.current}"
        puts "Upcoming events found: #{Event.upcoming.count}"
        
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