# Rolls per-agent figures up into the teams those agents belong to. An agent in two teams is
# counted in both, so team totals deliberately do not add up to the account total.
class V2::Reports::TeamMonitoringBuilder
  pattr_initialize [:account!, :teams!, :params!, :include_ungrouped!]

  def build
    {
      alerts: alerts,
      teams: teams.map { |team| team_row(team) },
      ungrouped_agents: ungrouped_agent_ids.map { |user_id| agent_row(user_id) }
    }
  end

  private

  def alerts
    waiting_since = unassigned_conversations.minimum(:waiting_since) ||
                    unassigned_conversations.minimum(:created_at)

    {
      unassigned_conversations: unassigned_conversations.count,
      longest_waiting_seconds: waiting_since && (Time.current - waiting_since).to_i,
      teams_without_supervisor: teams.count { |team| team.supervisor_id.blank? },
      ungrouped_agents: ungrouped_agent_ids.size
    }
  end

  def unassigned_conversations
    @unassigned_conversations ||= account.conversations.open.unassigned
  end

  def team_row(team)
    member_ids = team_member_ids[team.id] || []
    agents = member_ids.map { |user_id| agent_row(user_id) }

    {
      id: team.id,
      name: team.name,
      description: team.description,
      supervisor: supervisor_payload(team),
      members_count: member_ids.size,
      online_members_count: member_ids.count { |user_id| metrics.online_statuses[user_id.to_s] == 'online' },
      agents: agents
    }.merge(aggregate(agents))
  end

  def supervisor_payload(team)
    return if team.supervisor.blank?

    { id: team.supervisor.id, name: team.supervisor.available_name, thumbnail: team.supervisor.avatar_url }
  end

  def agent_row(user_id)
    user = users_by_id[user_id]

    {
      id: user_id,
      name: user&.available_name,
      thumbnail: user&.avatar_url,
      availability_status: metrics.online_statuses[user_id.to_s] || 'offline'
    }.merge(live_stats(user_id)).merge(period_stats(user_id))
  end

  def live_stats(user_id)
    {
      open_conversations: metrics.open_conversation_counts[user_id] || 0,
      open_contacts: metrics.open_contact_counts[user_id] || 0,
      capacity_limit: metrics.capacity_limits[user_id]
    }
  end

  def period_stats(user_id)
    summary = metrics.summaries[user_id] || {}

    {
      conversations_count: summary[:conversations_count] || 0,
      resolved_conversations_count: summary[:resolved_conversations_count] || 0,
      avg_first_response_time: summary[:avg_first_response_time],
      avg_resolution_time: summary[:avg_resolution_time],
      avg_reply_time: summary[:avg_reply_time],
      csat_score: metrics.csat_scores[user_id],
      csat_responses_count: metrics.csat_counts[user_id] || 0,
      sla_applied_count: metrics.sla_applied_counts[user_id],
      sla_missed_count: metrics.sla_missed_counts[user_id]
    }
  end

  def aggregate(agents)
    {
      open_conversations: agents.sum { |agent| agent[:open_conversations] },
      open_contacts: agents.sum { |agent| agent[:open_contacts] },
      conversations_count: agents.sum { |agent| agent[:conversations_count] },
      resolved_conversations_count: agents.sum { |agent| agent[:resolved_conversations_count] },
      avg_first_response_time: weighted_average(agents, :avg_first_response_time),
      avg_resolution_time: weighted_average(agents, :avg_resolution_time),
      avg_reply_time: weighted_average(agents, :avg_reply_time),
      csat_score: csat_average(agents),
      csat_responses_count: agents.sum { |agent| agent[:csat_responses_count] },
      sla_applied_count: sum_or_nil(agents, :sla_applied_count),
      sla_missed_count: sum_or_nil(agents, :sla_missed_count)
    }
  end

  # Durations are weighted by conversation volume so a member with two conversations does not
  # move the team average as much as one with fifty.
  def weighted_average(agents, key)
    weighted = agents.filter_map do |agent|
      next if agent[key].blank? || agent[:conversations_count].zero?

      [agent[key] * agent[:conversations_count], agent[:conversations_count]]
    end
    return if weighted.empty?

    (weighted.sum(&:first) / weighted.sum(&:last)).round(2)
  end

  def csat_average(agents)
    rated = agents.select { |agent| agent[:csat_responses_count].positive? && agent[:csat_score].present? }
    return if rated.empty?

    total = rated.sum { |agent| agent[:csat_score] * agent[:csat_responses_count] }
    (total / rated.sum { |agent| agent[:csat_responses_count] }.to_f).round(2)
  end

  def sum_or_nil(agents, key)
    values = agents.filter_map { |agent| agent[key] }
    values.empty? ? nil : values.sum
  end

  def team_member_ids
    @team_member_ids ||= TeamMember.where(team_id: teams.map(&:id)).pluck(:team_id, :user_id)
                                   .each_with_object({}) { |(team_id, user_id), acc| (acc[team_id] ||= []) << user_id }
  end

  def grouped_user_ids
    @grouped_user_ids ||= team_member_ids.values.flatten.uniq
  end

  # Only an administrator sees the whole account, so only they get the catch-all bucket.
  def ungrouped_agent_ids
    return [] unless include_ungrouped

    @ungrouped_agent_ids ||= account.account_users.pluck(:user_id) - grouped_user_ids
  end

  def visible_user_ids
    @visible_user_ids ||= (grouped_user_ids + ungrouped_agent_ids).uniq
  end

  def users_by_id
    @users_by_id ||= account.users.where(id: visible_user_ids).index_by(&:id)
  end

  def metrics
    @metrics ||= V2::Reports::TeamMonitoringMetrics.new(account: account, user_ids: visible_user_ids, params: params)
  end
end
