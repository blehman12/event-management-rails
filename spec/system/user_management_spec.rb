require 'rails_helper'

RSpec.describe 'User Management', type: :system do
  let!(:admin_user) { create(:user, :admin) }

  before do
    driven_by(:selenium_chrome_headless)
    login_as(admin_user, scope: :user)
  end

  describe 'User Creation' do
    it 'creates a new user successfully' do
      visit admin_users_path
      click_link 'New User'

      fill_in 'First name', with: 'John'
      fill_in 'Last name', with: 'Doe'
      fill_in 'Email', with: 'john.doe@example.com'
      fill_in 'Company', with: 'Test Company'
      fill_in 'Phone', with: '555-123-4567'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      select 'Attendee', from: 'Role'

      click_button 'Create User'

      expect(page).to have_content 'User was successfully created'
      expect(page).to have_content 'John Doe'
      expect(page).to have_content 'john.doe@example.com'
    end

    it 'validates required fields' do
      visit new_admin_user_path
      click_button 'Create User'

      expect(page).to have_content 'prohibited this user from being saved'
    end
  end

  describe 'User Editing' do
    let!(:user) { create(:user) }

    it 'updates user information' do
      visit edit_admin_user_path(user)

      fill_in 'First name', with: 'Updated'
      fill_in 'Company', with: 'New Company'

      click_button 'Update User'

      expect(page).to have_content 'User was successfully updated'
      expect(page).to have_content 'Updated'
      expect(page).to have_content 'New Company'
    end

    it 'prevents admin from demoting themselves' do
      visit edit_admin_user_path(admin_user)

      select 'Attendee', from: 'Role'
      click_button 'Update User'

      expect(page).to have_content 'You cannot remove your own admin privileges'
    end
  end

  describe 'User Listing' do
    let!(:users) { create_list(:user, 5) }

    it 'displays all users with pagination' do
      visit admin_users_path

      # Should show user names and emails
      users.take(3).each do |user|
        expect(page).to have_content "#{user.first_name} #{user.last_name}"
        expect(page).to have_content user.email
      end
    end
  end

  describe 'User Deletion' do
    let!(:user) { create(:user) }

    it 'deletes a user' do
      visit admin_user_path(user)

      accept_confirm do
        click_button 'Delete User'
      end

      expect(page).to have_content 'User was successfully deleted'
      expect(page).not_to have_content user.email
    end

    it 'prevents deletion of own account' do
      visit admin_user_path(admin_user)

      accept_confirm do
        click_button 'Delete User'
      end

      expect(page).to have_content 'You cannot delete your own account'
    end
  end
end
