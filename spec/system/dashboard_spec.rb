require 'rails_helper'

RSpec.describe 'Dashboard', type: :system do
  let!(:user) { create(:user) }
  let!(:venue) { create(:venue) }
  let!(:upcoming_event) { create(:event, :upcoming, venue: venue) }
  let!(:past_event) { create(:event, :past, venue: venue) }

  before do
    driven_by(:selenium_chrome_headless)
    login_as(user, scope: :user)
  end

  describe 'User Dashboard' do
    it 'displays upcoming events' do
      visit dashboard_index_path

      expect(page).to have_content upcoming_event.name
      expect(page).not_to have_content past_event.name
    end

    it 'shows event details' do
      visit dashboard_index_path

      expect(page).to have_content upcoming_event.name
      expect(page).to have_content upcoming_event.venue.name
      expect(page).to have_content upcoming_event.event_date.strftime('%B %d, %Y')
    end

    it 'provides navigation to admin areas for admin users' do
      admin = create(:user, :admin)
      login_as(admin, scope: :user)
      
      visit dashboard_index_path
      
      expect(page).to have_link 'Events'
      expect(page).to have_link 'Users'
      expect(page).to have_link 'Venues'
    end
  end
end
