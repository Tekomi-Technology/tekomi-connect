# Safety net for webhooks that never arrive: re-reads whatever changed at the source since the last run.
# Without an argument it fans out one job per enabled connection.
class TicketSources::ReconcileJob < TicketSources::BaseJob
  queue_as :scheduled_jobs

  def perform(connection_id = nil)
    return TicketSourceConnection.enabled.find_each { |connection| self.class.perform_later(connection.id) } if connection_id.nil?

    @connection = TicketSourceConnection.enabled.find_by(id: connection_id)
    TicketSources::SyncService.new(@connection).reconcile if @connection
  end
end
