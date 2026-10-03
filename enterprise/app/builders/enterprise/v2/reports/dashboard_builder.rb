module Enterprise::V2::Reports::DashboardBuilder
  MISSED_STATUSES = %w[missed active_with_misses].freeze

  def build
    super.merge(sla: sla)
  end

  private

  def sla
    current = applied_slas.where(created_at: range)
    missed = current.where(sla_status: MISSED_STATUSES)
    total = current.count

    {
      total: total,
      missed: missed.count,
      active: current.where(sla_status: :active).count,
      hit_rate: total.zero? ? nil : ((total - missed.count) * 100.0 / total).round(1),
      timeseries: sla_timeseries(current)
    }
  end

  def sla_timeseries(scope)
    missed_by_period = group_by_period(scope.where(sla_status: MISSED_STATUSES))
    group_by_period(scope).map do |time, total|
      missed = missed_by_period[time] || 0
      { timestamp: time.in_time_zone(sla_time_zone).to_i, hit: total - missed, missed: missed }
    end
  end

  def group_by_period(scope)
    scope.group_by_period(params[:group_by] || 'day', :created_at, default_value: 0, range: range,
                                                                   permit: %w[day week month hour],
                                                                   time_zone: sla_time_zone)
         .count
  end

  def sla_time_zone
    ActiveSupport::TimeZone[params[:timezone_offset].to_f]
  end

  def activity_events
    super + sla_missed_events
  end

  def sla_missed_events
    applied_slas.where(sla_status: MISSED_STATUSES).joins(:conversation).where(conversations: { inbox_id: list_inbox_ids })
                .order(updated_at: :desc).limit(self.class::RECENT_LIMIT).includes(conversation: :contact)
                .filter_map { |applied_sla| conversation_event('sla_missed', applied_sla.conversation, applied_sla.updated_at) }
  end

  def applied_slas
    scope = account.applied_slas
    inbox_id.present? ? scope.joins(:conversation).where(conversations: { inbox_id: inbox_id }) : scope
  end
end
