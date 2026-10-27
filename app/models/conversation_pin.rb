# == Schema Information
#
# Table name: conversation_pins
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_conversation_pins_on_conversation_id              (conversation_id)
#  index_conversation_pins_on_user_id_and_conversation_id  (user_id,conversation_id) UNIQUE
#
class ConversationPin < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :user_id }

  after_commit :invalidate_filtered_unread_counts, on: [:create, :destroy]

  private

  def invalidate_filtered_unread_counts
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).user_visibility_changed!(user_id: user_id)
  end
end
