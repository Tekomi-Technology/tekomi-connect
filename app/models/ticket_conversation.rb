class TicketConversation < ApplicationRecord
  belongs_to :ticket
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :ticket_id }
  validate :conversation_belongs_to_account

  private

  def conversation_belongs_to_account
    errors.add(:conversation, :invalid) if ticket && conversation && ticket.account_id != conversation.account_id
  end
end
