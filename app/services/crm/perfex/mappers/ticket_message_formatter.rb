class Crm::Perfex::Mappers::TicketMessageFormatter
  include ::Rails.application.routes.url_helpers

  ACTIVITY_NOTE_MAX_SIZE = 1800

  def self.transcript_text(conversation)
    new(conversation).transcript_text
  end

  def initialize(conversation)
    @conversation = conversation
  end

  def transcript_text
    I18n.with_locale(:en) { build_transcript_text }
  end

  private

  attr_reader :conversation

  def build_transcript_text
    return I18n.t('crm.no_message') if transcript_messages.empty?

    text = I18n.t('crm.ticket_message',
                   brand_name: escape(brand_name),
                   channel_info: escape(conversation.inbox.inbox_type),
                   company_line: company_line,
                   url: conversation_url_html,
                   format_messages: format_messages)

    text.gsub("\n", '<br>')
  end

  def transcript_messages
    @transcript_messages ||= conversation.messages.chat.select(&:conversation_transcriptable?)
  end

  def format_messages
    selected_messages = []
    separator = "\n\n"
    current_length = 0

    transcript_messages.reverse_each do |message|
      formatted_message = format_message(message)
      required_length = formatted_message.length + separator.length

      break unless (current_length + required_length) <= ACTIVITY_NOTE_MAX_SIZE

      selected_messages << formatted_message
      current_length += required_length
    end

    selected_messages.join(separator)
  end

  def format_message(message)
    <<~MESSAGE.strip
      [#{message_time(message)}] #{escape(sender_name(message))}: #{escape(message_content(message))}#{attachment_info(message)}
    MESSAGE
  end

  def message_time(message)
    message.created_at.in_time_zone(Time.zone).strftime('%Y-%m-%d %H:%M')
  end

  def sender_name(message)
    return 'System' if message.sender.nil?

    message.sender.name.presence || "#{message.sender_type} #{message.sender_id}"
  end

  def message_content(message)
    message.content.presence || I18n.t('crm.no_content')
  end

  def attachment_info(message)
    return '' unless message.attachments.any?

    attachments = message.attachments.map { |a| I18n.t('crm.attachment', type: escape(a.file_type)) }.join(', ')
    "\n#{attachments}"
  end

  def company_line
    company_name = conversation.contact.additional_attributes['company_name']
    return '' if company_name.blank?

    "\nCompany: #{escape(company_name)}"
  end

  def conversation_url
    app_account_conversation_url(account_id: conversation.account.id, id: conversation.display_id)
  end

  def conversation_url_html
    url = conversation_url
    "<a href=\"#{url}\">#{url}</a>"
  end

  def brand_name
    ::GlobalConfig.get('BRAND_NAME')['BRAND_NAME'] || 'Chatwoot'
  end

  def escape(text)
    ERB::Util.html_escape(text)
  end
end
