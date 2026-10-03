## Numbers behind the ticket report.
##
## Stage performance looks at passes through a stage, keyed on when the ticket entered it,
## so moving the date range never changes a pass that already happened. The workload
## figures are a snapshot of right now instead, because "what is late at this moment" is
## not a question about a past date range.
class Tickets::ReportBuilder
  pattr_initialize [:account!, :pipeline_id, :range!]

  def perform
    {
      stage_performance: stage_performance,
      workload: workload,
      sources: sources
    }
  end

  private

  def pipelines
    scope = account.pipelines.pipeline_type_ticket
    pipeline_id.present? ? scope.where(id: pipeline_id) : scope
  end

  def stages
    @stages ||= PipelineStage.where(pipeline_id: pipelines.select(:id)).order(:position, :id).to_a
  end

  def tickets
    @tickets ||= account.tickets.where(pipeline_id: pipelines.select(:id))
  end

  def stage_performance
    rows = stage_event_rows
    stages.map do |stage|
      row = rows[stage.id] || { total: 0, missed: 0, avg: nil }
      {
        stage_id: stage.id,
        stage_name: stage.name,
        total: row[:total],
        missed: row[:missed],
        on_time_rate: rate(row[:total] - row[:missed], row[:total]),
        avg_seconds: row[:avg]&.round
      }
    end
  end

  def stage_event_rows
    TicketStageEvent
      .where(ticket_id: tickets.select(:id), entered_at: range)
      .group(:pipeline_stage_id)
      .pluck(:pipeline_stage_id, Arel.sql('COUNT(*)'), Arel.sql('COUNT(missed_at)'), Arel.sql(average_duration_sql))
      .to_h { |stage_id, total, missed, avg| [stage_id, { total: total, missed: missed, avg: avg }] }
  end

  # Passes still in progress count from when they started until now.
  def average_duration_sql
    'AVG(EXTRACT(EPOCH FROM (COALESCE(exited_at, NOW()) - entered_at)))'
  end

  def workload
    open_tickets = tickets.where(stage_id: open_stages.map(&:id))
    totals = open_tickets.group(:stage_id).count
    at_risk = open_tickets.sla_status_at_risk.group(:stage_id).count
    breached = open_tickets.sla_status_breached.group(:stage_id).count

    open_stages.map do |stage|
      {
        stage_id: stage.id,
        stage_name: stage.name,
        open: totals[stage.id].to_i,
        at_risk: at_risk[stage.id].to_i,
        breached: breached[stage.id].to_i
      }
    end
  end

  # Counted one scope at a time rather than grouped, because a grouped count on an enum
  # column returns the stored integers on some Rails versions and the names on others.
  def sources
    scoped = tickets.where(created_at: range)
    total = scoped.count
    Ticket.defined_enums['created_by'].keys.map do |source|
      count = scoped.public_send("created_by_#{source}").count
      { source: source, count: count, share: rate(count, total) }
    end
  end

  def open_stages
    @open_stages ||= stages.select(&:open?)
  end

  def rate(part, total)
    return 0 if total.zero?

    ((part.to_f / total) * 100).round(1)
  end
end
