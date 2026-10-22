class TicketSources::PushStatusJob < TicketSources::BaseJob
  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    @connection = ticket&.external_link&.connection
    TicketSources::SyncService.new(@connection).push_status(ticket) if @connection&.enabled?
  end
end
