class ZaloOa::ConsultationWindow
  WINDOW = 48.hours
  FREE_LIMIT = 8
  NEAR_LIMIT_AT = 6
  LAST_INBOUND_KEY = 'zalo_oa_last_inbound_at'
  SENT_COUNT_KEY = 'zalo_oa_cs_sent_count'

  OUT_OF_WINDOW_NOTE = 'Zalo OA consultation window has expired; this reply may be rejected by Zalo.'
  LIMIT_REACHED_NOTE = 'Zalo OA free customer-service message limit reached for this consultation window.'

  class << self
    def record_inbound(conversation)
      conversation.with_lock do
        attrs = conversation.additional_attributes || {}
        conversation.update_columns(
          additional_attributes: attrs.merge(LAST_INBOUND_KEY => Time.current.iso8601, SENT_COUNT_KEY => 0),
          updated_at: Time.current
        )
      end
    end

    def record_outbound(conversation)
      warning = nil
      conversation.with_lock do
        attrs = conversation.additional_attributes || {}
        last_inbound_at = parse_time(attrs[LAST_INBOUND_KEY])
        count = attrs[SENT_COUNT_KEY].to_i

        if last_inbound_at.blank? || last_inbound_at < WINDOW.ago
          warning = OUT_OF_WINDOW_NOTE
        else
          count += 1
          warning = LIMIT_REACHED_NOTE if count == FREE_LIMIT
          warning = "Zalo OA consultation window is near its #{FREE_LIMIT}-message limit (#{count}/#{FREE_LIMIT})." if count == NEAR_LIMIT_AT
        end

        conversation.update_columns(
          additional_attributes: attrs.merge(SENT_COUNT_KEY => count),
          updated_at: Time.current
        )
        create_private_note(conversation, warning) if warning.present?
      end
    end

    private

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def create_private_note(conversation, content)
      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        private: true,
        content: content
      )
    end
  end
end
