# Gathers every per-agent figure the team monitoring screen needs, in one query per source.
class V2::Reports::TeamMonitoringMetrics
  pattr_initialize [:account!, :user_ids!, :params!]

  def online_statuses
    @online_statuses ||= OnlineStatusTracker.get_available_users(account.id) || {}
  end

  def open_conversation_counts
    @open_conversation_counts ||= open_conversations.group(:assignee_id).count
  end

  def open_contact_counts
    @open_contact_counts ||= open_conversations.group(:assignee_id).distinct.count(:contact_id)
  end

  def summaries
    @summaries ||= V2::Reports::AgentSummaryBuilder.new(account: account, params: params)
                                                   .build.index_by { |row| row[:id] }
  end

  # Capacity policies and SLA records only exist in the enterprise overlay.
  def capacity_limits
    return {} unless ChatwootApp.enterprise?

    @capacity_limits ||= begin
      policies = account.account_users.where(user_id: user_ids).where.not(agent_capacity_policy_id: nil)
                        .pluck(:user_id, :agent_capacity_policy_id)
      totals = InboxCapacityLimit.where(agent_capacity_policy_id: policies.map(&:last).uniq)
                                 .group(:agent_capacity_policy_id).sum(:conversation_limit)
      policies.to_h { |user_id, policy_id| [user_id, totals[policy_id]] }.compact
    end
  end

  def csat_counts
    @csat_counts ||= csat_responses.group(:assigned_agent_id).count
  end

  def csat_scores
    @csat_scores ||= csat_responses.group(:assigned_agent_id).average(:rating)
                                   .transform_values { |value| value.to_f.round(2) }
  end

  def sla_applied_counts
    return {} unless ChatwootApp.enterprise?

    @sla_applied_counts ||= applied_slas.group('conversations.assignee_id').count
  end

  def sla_missed_counts
    return {} unless ChatwootApp.enterprise?

    @sla_missed_counts ||= applied_slas.missed.group('conversations.assignee_id').count
  end

  private

  def open_conversations
    @open_conversations ||= account.conversations.open.where(assignee_id: user_ids)
  end

  def csat_responses
    @csat_responses ||= CsatSurveyResponse.where(account_id: account.id, assigned_agent_id: user_ids)
                                          .filter_by_created_at(range)
  end

  def applied_slas
    @applied_slas ||= AppliedSla.where(account_id: account.id).filter_by_date_range(range)
                                .joins(:conversation).where(conversations: { assignee_id: user_ids })
  end

  def range
    @range ||= params[:since]...params[:until]
  end
end
