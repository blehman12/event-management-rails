require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end

 describe 'GET #index' do
  let!(:event) { create(:event) }
  
  it 'returns a success response' do
    get :index
    expect(response).to be_successful
  end

  it 'assigns instance variables' do
    get :index
    expect(assigns(:current_event)).to be_present
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
