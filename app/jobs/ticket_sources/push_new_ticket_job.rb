class TicketSources::PushNewTicketJob < TicketSources::BaseJob
  def perform(connection_id, ticket_id)
    @connection = TicketSourceConnection.enabled.find_by(id: connection_id)
    ticket = Ticket.find_by(id: ticket_id)
    TicketSources::SyncService.new(@connection).push_new_ticket(ticket) if @connection && ticket
  end
end
