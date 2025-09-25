require 'rails_helper'

RSpec.describe 'Venue Management', type: :system do
  let!(:admin_user) { create(:user, :admin) }

  before do
    driven_by(:selenium_chrome_headless)
    login_as(admin_user, scope: :user)
  end

  describe 'Venue Creation' do
    it 'creates a new venue successfully' do
      visit admin_venues_path
      click_link 'New Venue'

      fill_in 'Name', with: 'Convention Center'
      fill_in 'Address', with: '123 Main Street, Portland, OR 97201'
      fill_in 'Description', with: 'Large convention center with multiple rooms'
      fill_in 'Capacity', with: '500'
      fill_in 'Contact info', with: 'manager@conventioncenter.com'

      click_button 'Create Venue'

      expect(page).to have_content 'Venue was successfully created'
      expect(page).to have_content 'Convention Center'
      expect(page).to have_content '123 Main Street'
    end

    it 'validates required fields' do
      visit new_admin_venue_path
      click_button 'Create Venue'

      expect(page).to have_content 'prohibited this venue from being saved'
    end
  end

  describe 'Venue Editing' do
    let!(:venue) { create(:venue) }

    it 'updates venue information' do
      visit edit_admin_venue_path(venue)

      fill_in 'Name', with: 'Updated Venue Name'
      fill_in 'Capacity', with: '750'

      click_button 'Update Venue'

      expect(page).to have_content 'Venue was successfully updated'
      expect(page).to have_content 'Updated Venue Name'
    end
  end

  describe 'Venue Listing' do
    let!(:venues) { create_list(:venue, 3) }

    it 'displays all venues' do
      visit admin_venues_path

      venues.each do |venue|
        expect(page).to have_content venue.name
        expect(page).to have_content venue.address
      end
    end
  end
end
