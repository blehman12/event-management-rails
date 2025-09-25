require 'rails_helper'

RSpec.describe 'Authentication', type: :system do
  let!(:user) { create(:user) }
  let!(:admin) { create(:user, :admin) }

  before do
    driven_by(:selenium_chrome_headless)
  end

  describe 'User Login' do
    it 'allows valid user to log in' do
      visit new_user_session_path

      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      expect(page).to have_content 'Signed in successfully'
    end

    it 'prevents invalid login' do
      visit new_user_session_path

      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'

      expect(page).to have_content 'Invalid Email or password'
    end
  end

  describe 'Admin Access' do
    it 'allows admin to access admin areas' do
      login_as(admin, scope: :user)
      visit admin_events_path

      expect(page).to have_content 'Events'
      expect(page).to have_link 'New Event'
    end

    it 'redirects regular users from admin areas' do
      login_as(user, scope: :user)
      visit admin_events_path

      expect(current_path).not_to eq(admin_events_path)
    end
  end

  describe 'User Registration' do
    it 'allows new user registration' do
      visit new_user_registration_path

      fill_in 'First name', with: 'New'
      fill_in 'Last name', with: 'User'
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      expect(page).to have_content 'Welcome! You have signed up successfully'
    end
  end

  describe 'User Logout' do
    it 'allows user to log out' do
      login_as(user, scope: :user)
      visit dashboard_index_path

      click_link 'Sign Out'

      expect(page).to have_content 'Signed out successfully'
    end
  end
end
