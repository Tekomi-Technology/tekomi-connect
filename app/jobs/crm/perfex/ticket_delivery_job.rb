class Crm::Perfex::TicketDeliveryJob < ApplicationJob
  queue_as :medium

  def perform(conversation, note)
    contact = conversation.contact
    contact_id = contact.additional_attributes.dig('external', 'perfex_contact_id')
    customer_id = contact.additional_attributes.dig('external', 'perfex_customer_id')
    return if contact_id.blank?

    message = "#{Crm::Perfex::Mappers::TicketMessageFormatter.transcript_text(conversation)}\n\n---\nGhi chú: #{note}"

    client = Crm::Perfex::Api::TicketClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    client.create_ticket(
      subject: "[Chatwoot ##{conversation.display_id}] #{contact.name}",
      message: message,
      department: ENV.fetch('EXTERNAL_TICKET_DEPARTMENT_ID'),
      userid: customer_id,
      contactid: contact_id
    )
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::TicketDeliveryJob failed for conversation #{conversation.id}: #{e.message}"
  end
end
