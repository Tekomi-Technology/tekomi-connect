# Chatwoot has no message reactions, so a Zalo reaction surfaces as a private note (agents only),
# threaded onto the reacted message when it can be resolved.
class Zalo::ReactionService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if reacted_message.blank?

    reacted_message.conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      private: true,
      content: note,
      content_attributes: { in_reply_to: reacted_message.id }
    )
  end

  private

  def reacted_message
    @reacted_message ||= inbox.messages.find_by(source_id: params[:reacted_msg_id].to_s)
  end

  def note
    who = params[:is_self] ? 'Bạn (từ app Zalo)' : params[:sender_name].presence || 'Khách'
    "#{params[:emoji]} #{who} đã thả cảm xúc"
  end
end
