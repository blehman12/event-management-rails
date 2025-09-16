class Admin::EventParticipantsController < Admin::BaseController
  before_action :set_event
  before_action :set_participant, only: [:update, :destroy]
  
  def index
    @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
    @users = User.where.not(id: @event.event_participants.select(:user_id)).order(:last_name, :first_name)
  end
  
  def create
    @participant = @event.event_participants.build(participant_params)
    
    if @participant.save
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant was successfully added.'
    else
      @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
      @users = User.where.not(id: @event.event_participants.select(:user_id)).order(:last_name, :first_name)
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error adding participant: ' + @participant.errors.full_messages.join(', ')
    end
  end
  
  def update
    if @participant.update(participant_update_params)
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant role was successfully updated.'
    else
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error updating participant.'
    end
  end
  
  def destroy
    @participant.destroy
    redirect_to admin_event_event_participants_path(@event), 
                notice: 'Participant was successfully removed.'
  end
  
  private
  
  def set_event
    @event = Event.find(params[:event_id])
  end
  
  def set_participant
    @participant = @event.event_participants.find(params[:id])
  end
  
  def participant_params
    params.require(:event_participant).permit(:user_id, :role, :notes)
  end
  
  def participant_update_params
    params.require(:event_participant).permit(:role, :notes)
  end
end
