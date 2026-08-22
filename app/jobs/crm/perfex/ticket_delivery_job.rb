class Crm::Perfex::TicketDeliveryJob < ApplicationJob
  queue_as :medium

  def perform(conversation, note)
    contact = conversation.contact
    userid = contact.additional_attributes.dig('external', 'perfex_id')
    return if userid.blank?

    message = "#{Crm::Perfex::Mappers::TicketMessageFormatter.transcript_text(conversation)}\n\n---\nGhi chú: #{note}"

    client = Crm::Perfex::Api::TicketClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    client.create_ticket(
      subject: "[Chatwoot ##{conversation.display_id}] #{contact.name}",
      message: message,
      department: ENV.fetch('EXTERNAL_TICKET_DEPARTMENT_ID'),
      userid: userid
    )
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::TicketDeliveryJob failed for conversation #{conversation.id}: #{e.message}"
  end
end
