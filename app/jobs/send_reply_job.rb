class SendReplyJob < ApplicationJob
  queue_as :high

  # A channel hiccup (timeout, rate limit, Zalo worker restarting) is retried for a few minutes.
  # Without this cap Sidekiq keeps retrying for weeks while the bubble still reads "sent", and the
  # reply can reach the customer days late; giving up marks it failed so the agent can resend.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.mark_failed(error)
  end
  discard_on ActiveRecord::RecordNotFound

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::ZaloOa' => ::ZaloOa::SendOnZaloOaService,
    'Channel::ZaloPersonal' => ::Zalo::SendOnZaloPersonalService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  def perform(message_id)
    message = Message.find(message_id)
    channel_name = message.conversation.inbox.channel.class.to_s

    return send_on_facebook_page(message) if channel_name == 'Channel::FacebookPage'

    service_class = CHANNEL_SERVICES[channel_name]
    return unless service_class

    service_class.new(message: message).perform
  end

  def mark_failed(error)
    message = Message.find_by(id: arguments.first)
    return if message.blank? || delivered?(message)

    Rails.logger.error("SendReplyJob gave up on message #{message.id}: #{error.class} #{error.message}")
    message.update!(status: :failed, external_error: I18n.t('errors.send_reply.failed'))
  end

  private

  # Channels that split attachments into separate sends record each id; a message is only
  # delivered once every attachment went out. Other channels set source_id once the send succeeds.
  def delivered?(message)
    ids = message.content_attributes['external_message_ids']
    return message.source_id.present? if ids.blank?

    ids.size >= message.attachments.size
  end

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end
end
