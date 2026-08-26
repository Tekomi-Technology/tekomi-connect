class PhoneCall < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  TERMINAL_STATUSES = %w[completed missed busy no_answer rejected cancelled failed].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :contact
  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :user, optional: true
  belongs_to :phone_extension, optional: true
  has_many :pbx_call_events, dependent: :destroy

  validates :pbx_id, :linked_id, :customer_number, :status, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :linked_id, uniqueness: { scope: :pbx_id }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def message_data
    {
      phone_call_id: id,
      pbx_call_id: linked_id,
      direction: direction,
      status: status,
      customer_number: customer_number,
      extension: extension,
      from_number: from_number,
      to_number: to_number,
      duration_seconds: duration_seconds,
      hangup_cause: hangup_cause,
      recording_url: recording_url,
      agent_id: user_id,
      agent_name: user&.available_name,
      started_at: started_at&.iso8601,
      answered_at: answered_at&.iso8601,
      ended_at: ended_at&.iso8601
    }.compact
  end
end
