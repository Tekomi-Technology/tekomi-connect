class Api::V1::Accounts::Conversations::TicketsController < Api::V1::Accounts::Conversations::BaseController
  include CrmTicketsFeatureConcern

  def index
    authorize Ticket, :index?
    @tickets = @conversation.tickets.includes(:contact, :assignee, :stage_events).order(created_at: :desc)
  end
end
