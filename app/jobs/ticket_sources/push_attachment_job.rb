class TicketSources::PushAttachmentJob < TicketSources::BaseJob
  def perform(ticket_id, blob_id)
    ticket = Ticket.find_by(id: ticket_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    @connection = ticket&.external_link&.connection
    TicketSources::SyncService.new(@connection).push_attachment(ticket, blob) if @connection&.enabled? && blob
  end
end
