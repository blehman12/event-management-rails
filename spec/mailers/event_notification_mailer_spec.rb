require "rails_helper"

RSpec.describe EventNotificationMailer, type: :mailer do
  describe "rsvp_confirmation" do
    let(:mail) { EventNotificationMailer.rsvp_confirmation }

    it "renders the headers" do
      expect(mail.subject).to eq("Rsvp confirmation")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

end
