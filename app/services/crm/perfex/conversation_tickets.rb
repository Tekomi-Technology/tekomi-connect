## Reads the CRM ticket references a conversation accumulated over time. Deliveries used to be
## stored one at a time under `crm_ticket`, so both shapes are normalised here.
class Crm::Perfex::ConversationTickets
  def self.entries(custom_attributes)
    attributes = custom_attributes || {}
    list = attributes['crm_tickets']
    return normalize(list) if list.is_a?(Array)

    legacy = attributes['crm_ticket']
    legacy.is_a?(Hash) ? normalize([legacy]) : []
  end

  def self.normalize(list)
    list.filter_map do |entry|
      next unless entry.is_a?(Hash)

      ticket_id = entry['ticket_id']
      next if ticket_id.blank?

      {
        'ticket_id' => ticket_id.to_s,
        'sent_at' => entry['sent_at'],
        'session_at' => entry['session_at']
      }
    end
  end
  private_class_method :normalize
end
