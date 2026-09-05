class Zalo::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  # Prefix on messages the operator sent directly from the native Zalo app.
  SELF_PREFIX = '📱 từ app Zalo'.freeze
  # Shown while the real group name has not been resolved — still better than a member's name.
  GROUP_FALLBACK_NAME = 'Nhóm Zalo'.freeze
  MAX_ATTACHMENT_SIZE = 40.megabytes

  def perform
    return if thread_id.blank? || source_id.blank?
    return if already_imported?

    set_contact
    set_conversation
    build_message
    attach_media
    @message.save!
  end

  private

  delegate :channel, to: :inbox

  def group?
    params[:kind] == 'group'
  end

  def self_message?
    params[:is_self] == true
  end

  def thread_id
    @thread_id ||= params[:thread_id].to_s
  end

  # Prefixed so a user id can never collide with a group id, and so the outbound path knows
  # which kind of thread to send to without a lookup.
  def contact_source_id
    @contact_source_id ||= "#{params[:kind]}:#{thread_id}"
  end

  def source_id
    @source_id ||= params[:msg_id].to_s
  end

  # An outbound reply with several attachments produces several Zalo ids. SendOnZaloPersonalService
  # records each one in Redis as it sends, so any echo is recognised — not just the first, which is
  # the only one stored in source_id.
  def already_imported?
    return true if inbox.messages.exists?(source_id: source_id)

    ::Redis::Alfred.exists?(format(::Redis::Alfred::ZALO_PERSONAL_SENT_MESSAGE, inbox_id: inbox.id, zalo_message_id: source_id))
  end

  def set_contact
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: contact_source_id,
      inbox: inbox,
      contact_attributes: { name: resolved_name }
    ).perform
    @contact = @contact_inbox.contact
    refresh_placeholder_name
  end

  # A group is one contact, so it must carry the group's own name; taking the sender's name would
  # label the thread after whoever happened to speak first.
  def resolved_name
    profile&.dig('name').presence || instant_name
  end

  def instant_name
    return GROUP_FALLBACK_NAME if group?
    # For a self-initiated thread the sender is the operator, not the other party, so fall back
    # to the thread id until the profile lookup fills in the real name.
    return thread_id if self_message?

    params[:sender_name].presence || thread_id
  end

  def profile
    @profile ||= ::Zalo::WorkerClient.profile(channel.id, params[:kind], thread_id)
  rescue ::Zalo::WorkerClient::Error => e
    Rails.logger.warn("Zalo personal profile lookup failed for #{contact_source_id}: #{e.message}")
    nil
  end

  # An earlier lookup may have failed and left a placeholder; correct it once a lookup succeeds.
  def refresh_placeholder_name
    return unless [GROUP_FALLBACK_NAME, thread_id].include?(@contact.name)

    name = profile&.dig('name').presence
    @contact.update!(name: name) if name.present?
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  def build_message
    @message = @conversation.messages.build(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: self_message? ? :outgoing : :incoming,
      sender: self_message? ? nil : @contact,
      content: message_content,
      source_id: source_id,
      content_attributes: content_attributes
    )
  end

  def message_content
    body = params[:content].to_s
    return [SELF_PREFIX, body.presence].compact.join("\n") if self_message?
    # Every message in a group lands under the single group contact, so name who is speaking.
    return "**#{params[:sender_name]}:**\n#{body}" if group? && params[:sender_name].present?

    body.presence
  end

  def content_attributes
    attributes = { zalo_quote_source: params[:quote_source] }
    return attributes if params[:quote_msg_id].blank?

    attributes[:in_reply_to_external_id] = params[:quote_msg_id].to_s
    quoted = inbox.messages.find_by(source_id: params[:quote_msg_id].to_s)
    attributes[:in_reply_to] = quoted.id if quoted
    attributes
  end

  def attach_media
    return if media.blank?

    file = Down.download(media[:url], max_size: MAX_ATTACHMENT_SIZE, open_timeout: 10, read_timeout: 30)
    @message.attachments.new(
      account_id: inbox.account_id,
      file_type: media[:type],
      file: { io: file, filename: media[:filename].presence || "zalo-#{source_id}", content_type: file.content_type }
    )
  end

  def media
    @media ||= params[:media].presence
  end
end
