class Crm::Perfex::TicketDeliveryJob < ApplicationJob
  queue_as :medium

  retry_on Crm::Perfex::Api::BaseClient::ApiError, wait: :polynomially_longer, attempts: 5 do |job, error|
    conversation = Conversation.find_by(id: job.arguments.first.id)
    conversation&.update!(
      custom_attributes: (conversation.custom_attributes || {}).merge(
        'crm_ticket_error' => error.message.truncate(500),
        'crm_ticket_failed_at' => Time.current.iso8601
      )
    )
  end

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
    response = client.create_ticket(
      subject: subject_for(contact),
      message: message,
      department: ENV.fetch('EXTERNAL_TICKET_DEPARTMENT_ID'),
      userid: customer_id,
      contactid: contact_id
    )

    record_delivery(conversation, response)
  end

  private

  def subject_for(contact)
    company_name = contact.company&.name
    return "[Tekomi Chatbot] #{contact.name}" if company_name.blank?

    "[Tekomi Chatbot] #{company_name} - #{contact.name}"
  end

  def record_delivery(conversation, response)
    data = response.is_a?(Hash) ? response.fetch('data', {}) : {}
    ticket_id = data['ticketid'] || data['id']

    delivery = { 'sent_at' => Time.current.iso8601 }
    delivery['ticket_id'] = ticket_id if ticket_id.present?

    custom_attributes = (conversation.custom_attributes || {}).except('crm_ticket_error', 'crm_ticket_failed_at')
    conversation.update!(custom_attributes: custom_attributes.merge('crm_ticket' => delivery))
  end
end
