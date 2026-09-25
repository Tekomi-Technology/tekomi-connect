class ZaloOa::RequestInfoJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank? || !conversation.inbox.channel.is_a?(Channel::ZaloOa)
    return unless enabled? && image_url.present?

    claimed = claim(conversation)
    return unless claimed

    channel = conversation.inbox.channel
    ZaloOa::Client.send_request_user_info(
      access_token: channel.valid_access_token,
      user_id: conversation.contact_inbox.source_id,
      title: ENV.fetch('ZALO_OA_REQUEST_USER_INFO_TITLE', 'Share your contact information'),
      subtitle: ENV.fetch('ZALO_OA_REQUEST_USER_INFO_SUBTITLE', 'Help us serve you better'),
      image_url: image_url
    )
  rescue ZaloOa::Client::Error
    # Zalo accepted or rejected the card; keep the once-per-conversation claim to avoid spam.
    raise
  rescue StandardError
    release_claim(conversation) if conversation.present?
    raise
  end

  private

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ZALO_OA_REQUEST_USER_INFO_ENABLED', 'false'))
  end

  def image_url
    ENV['ZALO_OA_REQUEST_USER_INFO_IMAGE_URL'].presence
  end

  def claim(conversation)
    claimed = false
    conversation.with_lock do
      attrs = conversation.additional_attributes || {}
      next if attrs['zalo_oa_info_requested_at'].present?

      conversation.update_columns(
        additional_attributes: attrs.merge('zalo_oa_info_requested_at' => Time.current.iso8601),
        updated_at: Time.current
      )
      claimed = true
    end
    claimed
  end

  def release_claim(conversation)
    conversation.with_lock do
      attrs = conversation.additional_attributes || {}
      conversation.update_columns(
        additional_attributes: attrs.except('zalo_oa_info_requested_at'),
        updated_at: Time.current
      )
    end
  end
end
