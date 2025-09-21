require "rails_helper"

RSpec.describe EventNotificationMailer, type: :mailer do
  describe "rsvp_confirmation" do
    let(:participant) { create(:event_participant, :confirmed) }
    let(:mail) { EventNotificationMailer.rsvp_confirmation(participant) }
    
    it "renders the headers" do
      expect(mail.subject).to eq("RSVP Confirmed: #{participant.event.name}")
      expect(mail.to).to eq([participant.user.email])
      expect(mail.from).to eq([ENV['GMAIL_USERNAME'] || 'noreply@example.com'])
    end
    
    it "renders the body" do
      expect(mail.body.encoded).to match(participant.user.first_name)
      expect(mail.body.encoded).to match(participant.event.name)
    end
  end
end