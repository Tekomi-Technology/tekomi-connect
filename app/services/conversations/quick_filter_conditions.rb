module Conversations::QuickFilterConditions
  module_function

  def unread
    'EXISTS (SELECT 1 FROM messages WHERE messages.conversation_id = conversations.id ' \
      'AND messages.account_id = conversations.account_id ' \
      "AND messages.message_type = #{Message.message_types[:incoming]} " \
      'AND (conversations.agent_last_seen_at IS NULL OR messages.created_at > conversations.agent_last_seen_at))'
  end

  def unattended
    '(conversations.first_reply_created_at IS NULL OR conversations.waiting_since IS NOT NULL)'
  end

  def unassigned
    'conversations.assignee_id IS NULL'
  end

  def assigned_to(user_id)
    "conversations.assignee_id = #{user_id.to_i}"
  end

  def pinned_by(user_id)
    'EXISTS (SELECT 1 FROM conversation_pins WHERE conversation_pins.conversation_id = conversations.id ' \
      "AND conversation_pins.user_id = #{user_id.to_i})"
  end

  def mentioning(user_id)
    "EXISTS (SELECT 1 FROM mentions WHERE mentions.conversation_id = conversations.id AND mentions.user_id = #{user_id.to_i})"
  end

  def participated_by(user_id)
    'EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_participants.conversation_id = conversations.id ' \
      "AND conversation_participants.user_id = #{user_id.to_i})"
  end

  def group_thread
    'EXISTS (SELECT 1 FROM contact_inboxes WHERE contact_inboxes.id = conversations.contact_inbox_id ' \
      "AND contact_inboxes.source_id LIKE '#{Conversation::GROUP_THREAD_SOURCE_PREFIX}%')"
  end

  def direct_thread
    "NOT #{group_thread}"
  end
end
