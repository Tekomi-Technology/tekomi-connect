class ConversationPin < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :user_id }
end
