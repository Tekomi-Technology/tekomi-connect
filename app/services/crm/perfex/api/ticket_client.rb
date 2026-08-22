class Crm::Perfex::Api::TicketClient < Crm::Perfex::Api::BaseClient
  def create_ticket(subject:, message:, department:, userid:)
    post('tickets', { subject: subject, message: message, department: department, userid: userid })
  end
end
