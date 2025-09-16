class Venue < ApplicationRecord
  has_many :events, dependent: :destroy
  
  validates :name, :address, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :name, uniqueness: true

  scope :available_for_date, ->(date) { 
    where.not(id: Event.where(event_date: date.beginning_of_day..date.end_of_day).select(:venue_id))
  }

  def full_address
    "#{name}, #{address}"
  end

  def events_count
    events.count
  end

  def upcoming_events
    events.upcoming.order(:event_date)
  end
end

  # Helper methods for admin interface
  def events_count
    events.count
  end
  
  def upcoming_events
    events.where('event_date >= ?', Time.current)
  end
  
  def full_address
    address
  end
