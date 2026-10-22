class TicketSources::PushCommentJob < TicketSources::BaseJob
  def perform(activity_id)
    activity = TicketActivity.find_by(id: activity_id)
    @connection = activity&.ticket&.external_link&.connection
    TicketSources::SyncService.new(@connection).push_comment(activity) if @connection&.enabled?
  end
end
