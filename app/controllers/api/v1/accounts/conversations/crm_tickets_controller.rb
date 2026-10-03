class Api::V1::Accounts::Conversations::CrmTicketsController < Api::V1::Accounts::Conversations::BaseController
  include CrmTicketsFeatureConcern

  def index
    entries = Crm::Perfex::ConversationTickets.entries(@conversation.custom_attributes)
    return render json: { payload: [] } if entries.empty? || !Crm::Perfex::Config.configured?

    render json: { payload: fetch_tickets(entries) }
  end

  private

  def fetch_tickets(entries)
    client = Crm::Perfex::Api::TicketClient.new(
      base_url: Crm::Perfex::Config.system_url,
      api_key: Crm::Perfex::Config.api_key
    )

    # A ticket deleted in the CRM must not blank out the rest of the panel.
    entries.reverse.filter_map { |entry| fetch_one(client, entry) }
  end

  def fetch_one(client, entry)
    ticket = client.fetch_ticket(entry['ticket_id'])
    return if ticket.blank?

    ticket.slice('ticketid', 'subject', 'status', 'priority', 'department', 'date', 'lastreply')
          .merge('sent_at' => entry['sent_at'])
  rescue Crm::Perfex::Api::BaseClient::ApiError => e
    Rails.logger.warn "Crm::Perfex ticket #{entry['ticket_id']} unavailable: #{e.message}"
    nil
  end
end
