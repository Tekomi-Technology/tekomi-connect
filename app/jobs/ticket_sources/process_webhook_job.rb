class TicketSources::ProcessWebhookJob < TicketSources::BaseJob
  def perform(connection_id, payload)
    @connection = TicketSourceConnection.enabled.find_by(id: connection_id)
    return unless @connection

    event = @connection.adapter.parse_webhook(payload)
    service = TicketSources::SyncService.new(@connection)
    case event[:type]
    when :ticket_changed then service.pull(event[:external_id])
    when :ticket_deleted then service.remove(event[:external_id])
    end
  end
end
