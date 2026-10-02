# Aggregates everything the overview dashboard shows in one payload.
# Totals cover the whole account (or one inbox); lists that link to
# conversations only include inboxes the user can access.
class V2::Reports::DashboardBuilder
  TIMESERIES_METRICS = %w[conversations_count resolutions_count avg_first_response_time avg_resolution_time].freeze
  ACTIVITY_LIMIT = 8
  RECENT_LIMIT = 5

  pattr_initialize [:account!, :user!, :params!]

  def build
    {
      summary: summary,
      timeseries: timeseries,
      live: live,
      channels: channels,
      first_response_distribution: first_response_distribution,
      csat: csat,
      activity: activity
    }
  end

  private

  def summary
    metric_builder(range_params).summary.merge(previous: metric_builder(previous_range_params).summary)
  end

  def timeseries
    series = TIMESERIES_METRICS.index_with { |metric| report_builder(range_params, metric).timeseries }
    series.merge(previous_conversations_count: report_builder(previous_range_params, 'conversations_count').timeseries)
  end

  def live
    open = conversations.open
    {
      open: open.count,
      pending: conversations.pending.count,
      unassigned: open.unassigned.count,
      unattended: open.unattended.count,
      starred_waiting: open.joins(:contact).where(contacts: { vip: true }).where.not(waiting_since: nil).count
    }
  end

  def channels
    counts = conversations.where(created_at: range).joins(:inbox).group('inboxes.channel_type', 'conversations.status').count
    grouped = counts.each_with_object({}) do |((channel_type, status), count), result|
      channel = result[channel_type] ||= { channel_type: channel_type, total: 0, open: 0, resolved: 0 }
      channel[:total] += count
      channel[status.to_sym] = count if %w[open resolved].include?(status)
    end
    grouped.values.sort_by { |channel| -channel[:total] }
  end

  def first_response_distribution
    V2::Reports::FirstResponseTimeDistributionBuilder.new(account: account, params: params.slice(:since, :until))
                                                     .build.values.each_with_object(Hash.new(0)) do |buckets, total|
      buckets.each { |bucket, count| total[bucket] += count }
    end
  end

  def csat
    current = csat_responses(range)
    {
      average: current.average(:rating)&.to_f&.round(2),
      previous_average: csat_responses(previous_range).average(:rating)&.to_f&.round(2),
      total: current.count,
      distribution: current.group(:rating).count,
      recent: current.where(inbox_scope_for_lists).includes(:contact, :conversation).order(created_at: :desc).limit(RECENT_LIMIT)
                     .map { |response| csat_item(response) }
    }
  end

  def activity
    activity_events.sort_by { |event| -event[:timestamp] }.first(ACTIVITY_LIMIT)
  end

  def activity_events
    resolved_events + starred_waiting_events + csat_events
  end

  def resolved_events
    ReportingEvent.where(account_id: account.id, name: 'conversation_resolved', inbox_id: list_inbox_ids)
                  .order(created_at: :desc).limit(RECENT_LIMIT).includes(conversation: :contact)
                  .filter_map { |event| conversation_event('resolved', event.conversation, event.created_at) }
  end

  def starred_waiting_events
    conversations.open.where(inbox_id: list_inbox_ids).joins(:contact).where(contacts: { vip: true })
                 .where.not(waiting_since: nil).order(waiting_since: :desc).limit(RECENT_LIMIT).includes(:contact)
                 .map { |conversation| conversation_event('starred_waiting', conversation, conversation.waiting_since) }
  end

  def csat_events
    account.csat_survey_responses.where(inbox_scope_for_lists).includes(:contact, :conversation)
           .order(created_at: :desc).limit(RECENT_LIMIT)
           .map { |response| csat_item(response).merge(type: 'csat') }
  end

  def conversation_event(type, conversation, time)
    return if conversation.nil?

    {
      type: type,
      display_id: conversation.display_id,
      contact_name: conversation.contact&.name,
      timestamp: time.to_i
    }
  end

  def csat_item(response)
    {
      rating: response.rating,
      feedback: response.feedback_message,
      contact_name: response.contact&.name,
      display_id: response.conversation&.display_id,
      timestamp: response.created_at.to_i
    }
  end

  def csat_responses(time_range)
    scope = account.csat_survey_responses.where(created_at: time_range)
    inbox_id.present? ? scope.joins(:conversation).where(conversations: { inbox_id: inbox_id }) : scope
  end

  def inbox_scope_for_lists
    { conversation_id: account.conversations.where(inbox_id: list_inbox_ids).select(:id) }
  end

  def list_inbox_ids
    @list_inbox_ids ||= begin
      ids = user.assigned_inboxes.pluck(:id)
      inbox_id.present? ? ids & [inbox_id.to_i] : ids
    end
  end

  def conversations
    scope = account.conversations
    inbox_id.present? ? scope.where(inbox_id: inbox_id) : scope
  end

  def metric_builder(builder_params)
    V2::Reports::Conversations::MetricBuilder.new(account, builder_params)
  end

  def report_builder(builder_params, metric)
    V2::Reports::Conversations::ReportBuilder.new(account, builder_params.merge(metric: metric))
  end

  def range_params
    base_params.merge(since: params[:since], until: params[:until])
  end

  def previous_range_params
    base_params.merge(since: previous_since.to_s, until: params[:since])
  end

  def base_params
    {
      type: inbox_id.present? ? :inbox : :account,
      id: inbox_id,
      group_by: params[:group_by] || 'day',
      timezone_offset: params[:timezone_offset],
      business_hours: false
    }
  end

  def range
    Time.zone.at(params[:since].to_i)...Time.zone.at(params[:until].to_i)
  end

  def previous_range
    Time.zone.at(previous_since)...Time.zone.at(params[:since].to_i)
  end

  def previous_since
    params[:since].to_i - (params[:until].to_i - params[:since].to_i)
  end

  def inbox_id
    params[:inbox_id]
  end
end

V2::Reports::DashboardBuilder.prepend_mod_with('V2::Reports::DashboardBuilder')
