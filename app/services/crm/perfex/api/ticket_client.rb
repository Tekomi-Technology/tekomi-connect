class Crm::Perfex::Api::TicketClient < Crm::Perfex::Api::BaseClient
  def create_ticket(subject:, message:, department:, userid:, contactid: nil)
    payload = { subject: subject, message: message, department: department, userid: userid }
    payload[:contactid] = contactid if contactid.present?

    post('tickets', payload)
  end
end
