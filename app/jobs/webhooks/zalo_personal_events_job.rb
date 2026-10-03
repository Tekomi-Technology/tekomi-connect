class Webhooks::ZaloPersonalEventsJob < MutexApplicationJob
  queue_as :low
  # Retry budget (19 × 2s = 38s) must exceed the 30s lock TTL set in `perform`, otherwise an
  # event arriving just after the lock is taken can exhaust retries and silently drop its message.
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20

  def perform(params = {})
    @params = params.with_indifferent_access
    channel = ::Channel::ZaloPersonal.find_by(id: @params[:channel_id])
    return if channel.blank? || channel.inbox.blank?

    # Serialize per (inbox, thread) so the first event creates the conversation and the rest
    # append. 30s TTL covers the attachment download; the 1s default expires mid-processing.
    key = format(::Redis::Alfred::ZALO_PERSONAL_MESSAGE_MUTEX, inbox_id: channel.inbox.id, thread_id: @params[:thread_id])
    with_lock(key, 30.seconds) do
      dispatch(channel.inbox)
    end
  end

  private

  def dispatch(inbox)
    case @params[:event]
    when 'message' then ::Zalo::IncomingMessageService.new(inbox: inbox, params: @params).perform
    when 'reaction' then ::Zalo::ReactionService.new(inbox: inbox, params: @params).perform
    when 'undo' then ::Zalo::UndoService.new(inbox: inbox, params: @params).perform
    end
  end
end
