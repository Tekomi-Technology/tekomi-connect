class Api::V1::Accounts::Contacts::TicketsController < Api::V1::Accounts::Contacts::BaseController
  include CrmTicketsFeatureConcern

  def index
    authorize Ticket, :index?
    @tickets = @contact.tickets.includes(:contact, :assignee, :stage_events).order(created_at: :desc)
  end
end
