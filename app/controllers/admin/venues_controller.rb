class Admin::VenuesController < Admin::BaseController
  before_action :set_venue, only: [:show, :edit, :update, :destroy]
  
  def index
    @venues = Venue.includes(:events).order(:name)
  end
  
  def show
    @upcoming_events = @venue.events.where('event_date >= ?', Time.current).order(:event_date)
  end
  
  def new
    @venue = Venue.new
  end
  
  def create
    @venue = Venue.new(venue_params)
    
    if @venue.save
      redirect_to admin_venue_path(@venue), notice: 'Venue was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @venue.update(venue_params)
      redirect_to admin_venue_path(@venue), notice: 'Venue was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    if @venue.events.empty?
      @venue.destroy
      redirect_to admin_venues_path, notice: 'Venue was successfully deleted.'
    else
      redirect_to admin_venue_path(@venue), alert: 'Cannot delete venue with existing events.'
    end
  end
  
  private
  
  def set_venue
    @venue = Venue.find(params[:id])
  end
  
  def venue_params
    params.require(:venue).permit(:name, :address, :capacity, :description, :contact_info)
  end
end
