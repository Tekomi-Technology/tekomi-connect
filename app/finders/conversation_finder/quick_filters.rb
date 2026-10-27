module ConversationFinder::QuickFilters
  QUICK_FILTERS = %w[unread unattended unassigned pinned direct group mention participating vip].freeze

  private

  def filter_by_quick_filter
    return unless QUICK_FILTERS.include?(params[:filter])

    @conversations = case params[:filter]
                     when 'mention', 'participating', 'unattended'
                       scoped_by_conversation_type(@conversations, params[:filter])
                     when 'vip'
                       @conversations.where(contact_id: vip_contacts)
                     else
                       @conversations.where(quick_filter_condition(params[:filter]))
                     end
  end

  def quick_filter_condition(filter)
    conditions = Conversations::QuickFilterConditions
    {
      'unread' => conditions.unread,
      'unassigned' => conditions.unassigned,
      'pinned' => conditions.pinned_by(current_user.id),
      'direct' => conditions.direct_thread,
      'group' => conditions.group_thread
    }.fetch(filter)
  end
end
