class CalendarController < ApplicationController
  before_action :authenticate_user!

  def show
    @event = Event.find(params[:event_id])
  end

  def export
    @event = Event.find(params[:event_id])
    
    cal = Icalendar::Calendar.new
    cal.event do |e|
      e.dtstart     = @event.start_date || @event.event_date
      e.dtend       = @event.end_date || (@event.start_date || @event.event_date) + 2.hours
      e.summary     = @event.name
      e.description = @event.description
      e.location    = @event.venue&.address || @event.venue&.name
      e.url         = event_url(@event) if defined?(event_url)
    end

    send_data cal.to_ical, 
              filename: "#{@event.name.parameterize}.ics",
              type: 'text/calendar',
              disposition: 'attachment'
  end

  def export_all
    @events = current_user.events.upcoming.order(:event_date)
    
    cal = Icalendar::Calendar.new
    @events.each do |event|
      cal.event do |e|
        e.dtstart     = event.start_date || event.event_date
        e.dtend       = event.end_date || (event.start_date || event.event_date) + 2.hours
        e.summary     = event.name
        e.description = event.description
        e.location    = event.venue&.address || event.venue&.name
        e.url         = event_url(event) if defined?(event_url)
      end
    end

    send_data cal.to_ical, 
              filename: "my-events-#{Date.current.strftime('%Y%m%d')}.ics",
              type: 'text/calendar',
              disposition: 'attachment'
  end
end
