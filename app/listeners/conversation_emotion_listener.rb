class ConversationEmotionListener < BaseListener
  def conversation_resolved(event)
    conversation = event.data[:conversation]
    return if conversation.inbox.channel_type == 'Channel::Phone'

    target_message_id = event.data[:resolved_message_id].to_i
    return if target_message_id.zero?

    ConversationEmotionAnalysisJob.perform_later(conversation.id, target_message_id, event.timestamp)
  end
end
