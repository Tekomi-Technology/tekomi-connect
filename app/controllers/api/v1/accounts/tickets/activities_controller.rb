class Api::V1::Accounts::Tickets::ActivitiesController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :fetch_ticket

  def index
    authorize @ticket, :show?
    @activities = @ticket.activities.includes(:actor)
  end

  def create
    authorize @ticket, :update?
    @activity = @ticket.activities.create!(
      actor: Current.user,
      action: TicketActivity::NOTE_ACTION,
      metadata: { content: params.require(:content) }
    )
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end
end
