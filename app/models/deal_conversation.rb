class DealConversation < ApplicationRecord
  belongs_to :deal
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :deal_id }
  validate :conversation_belongs_to_account

  private

  def conversation_belongs_to_account
    errors.add(:conversation, :invalid) if deal && conversation && deal.account_id != conversation.account_id
  end
end
