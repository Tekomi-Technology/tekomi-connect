# Backs the conversation list tabs Mở / Đang xử lý / Đã xử lý. A stage combines status and assignee,
# so a stage request lists every status and the stage condition narrows it down.
module ConversationFinder::Stages
  STAGES = %w[open in_progress resolved].freeze

  private

  def stage_requested?
    STAGES.include?(params[:stage])
  end

  # open: nobody has picked it up yet; in_progress: an agent has it, the AI is answering (pending) or it is
  # snoozed; resolved: closed.
  # «My inbox» (conversation_type mine) only lists the agent's own conversations, so there open means
  # no agent has replied yet.
  def stage_conditions
    statuses = Conversation.statuses
    open_split = params[:conversation_type] == 'mine' ? 'conversations.first_reply_created_at' : 'conversations.assignee_id'
    {
      'open' => "conversations.status = #{statuses[:open]} AND #{open_split} IS NULL",
      'in_progress' => "(conversations.status = #{statuses[:open]} AND #{open_split} IS NOT NULL) " \
                       "OR conversations.status IN (#{statuses[:pending]}, #{statuses[:snoozed]})",
      'resolved' => "conversations.status = #{statuses[:resolved]}"
    }
  end

  def stage_counts
    return {} unless stage_requested?

    relation = @conversations.unscope(:order)
    counts = if relation.eager_loading? || relation.limit_value || relation.offset_value
               stage_conditions.values.map { |condition| relation.where(condition).count }
             else
               relation.pick(*stage_conditions.values.map { |condition| Arel.sql("COUNT(*) FILTER (WHERE #{condition})") })
             end
    STAGES.zip(counts || [0, 0, 0]).to_h { |stage, count| [:"#{stage}_count", count] }
  end

  def filter_by_stage
    return unless stage_requested?

    @conversations = @conversations.where(stage_conditions[params[:stage]])
  end
end
