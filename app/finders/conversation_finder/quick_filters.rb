module ConversationFinder::QuickFilters
  QUICK_FILTERS = %w[unread unanswered unassigned ai pinned direct group].freeze

  def perform_filter_counts
    set_up
    relation = @conversations.unscope(:order).where.not(status: :resolved)
    counts = { filters: filter_counts(relation), labels: label_counts(relation) }
    return counts if params[:conversation_type] == 'mine'

    counts.merge(teams: relation.where.not(team_id: nil).group(:team_id).count, folders: folder_counts)
  end

  private

  def filter_by_quick_filter
    return unless QUICK_FILTERS.include?(params[:filter])

    @conversations = @conversations.where(quick_filter_conditions[params[:filter]])
  end

  def quick_filter_conditions
    group_thread = 'EXISTS (SELECT 1 FROM contact_inboxes WHERE contact_inboxes.id = conversations.contact_inbox_id ' \
                   "AND contact_inboxes.source_id LIKE 'group:%')"
    {
      'unread' => 'EXISTS (SELECT 1 FROM messages WHERE messages.conversation_id = conversations.id ' \
                  "AND messages.account_id = conversations.account_id AND messages.message_type = #{Message.message_types[:incoming]} " \
                  'AND (conversations.agent_last_seen_at IS NULL OR messages.created_at > conversations.agent_last_seen_at))',
      'unanswered' => '(conversations.first_reply_created_at IS NULL OR conversations.waiting_since IS NOT NULL)',
      'unassigned' => 'conversations.assignee_id IS NULL',
      'ai' => "conversations.status = #{Conversation.statuses[:pending]}",
      'pinned' => 'EXISTS (SELECT 1 FROM conversation_pins WHERE conversation_pins.conversation_id = conversations.id ' \
                  "AND conversation_pins.user_id = #{current_user.id})",
      'group' => group_thread,
      'direct' => "NOT #{group_thread}"
    }
  end

  def filter_counts(relation)
    mentioned = current_account.mentions.where(user: current_user).select(:conversation_id)
    participating = ConversationParticipant.where(account_id: current_account.id, user_id: current_user.id).select(:conversation_id)
    conditions = quick_filter_conditions.merge(
      'all' => 'TRUE',
      'mention' => "conversations.id IN (#{mentioned.to_sql})",
      'participating' => "conversations.id IN (#{participating.to_sql})"
    )
    values = relation.pick(*conditions.values.map { |condition| Arel.sql("COUNT(*) FILTER (WHERE #{condition})") })
    conditions.keys.zip(values).to_h
  end

  def label_counts(relation)
    ActsAsTaggableOn::Tagging.joins(:tag)
                             .where(taggable_type: 'Conversation', context: 'labels', taggable_id: relation.select(:id))
                             .group('tags.name')
                             .count
  end

  def folder_counts
    current_user.custom_filters.where(account: current_account, filter_type: :conversation).to_h do |folder|
      filter = Conversations::FilterService.new(folder.query.with_indifferent_access, current_user, current_account)
      [folder.id, filter.perform[:count][:all_count]]
    end
  end
end
