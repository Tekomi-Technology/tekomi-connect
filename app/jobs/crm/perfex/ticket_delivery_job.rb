class Crm::Perfex::TicketDeliveryJob < ApplicationJob
  queue_as :medium

  def perform(conversation, note)
    contact = conversation.contact
    contact_id = contact.additional_attributes.dig('external', 'perfex_contact_id')
    customer_id = contact.additional_attributes.dig('external', 'perfex_customer_id')
    return if contact_id.blank?

    transcript = Crm::Perfex::Mappers::TicketMessageFormatter.transcript_text(conversation)
    message = "#{transcript}<br><br>---<br>Ghi chú: #{ERB::Util.html_escape(note)}"

    client = Crm::Perfex::Api::TicketClient.new(
      base_url: ENV.fetch('EXTERNAL_TICKET_SYSTEM_URL'),
      api_key: ENV.fetch('EXTERNAL_TICKET_SYSTEM_API_KEY')
    )
    client.create_ticket(
      subject: "[Tekomi Chatbot] #{contact.name}",
      message: message,
      department: ENV.fetch('EXTERNAL_TICKET_DEPARTMENT_ID'),
      userid: customer_id,
      contactid: contact_id
    )
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.error "Crm::Perfex::TicketDeliveryJob failed for conversation #{conversation.id}: #{e.message}"
  end
end
