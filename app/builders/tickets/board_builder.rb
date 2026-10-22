# Read-only kanban snapshot of one ticket pipeline for the reports page: every stage with its total and its most
# recently updated tickets, plus the figures needed to pick between pipelines.
class Tickets::BoardBuilder
  TICKETS_PER_STAGE = 50

  pattr_initialize [:account!, :pipeline_id]

  def perform
    pipelines = account.pipelines.pipeline_type_ticket.order(:position, :id).to_a
    pipeline = pipelines.find { |candidate| candidate.id == pipeline_id.to_i } || pipelines.first
    return { pipelines: [], pipeline: nil, stages: [] } unless pipeline

    {
      pipelines: pipelines.map { |candidate| pipeline_summary(candidate) },
      pipeline: pipeline_summary(pipeline),
      stages: stages_with_tickets(pipeline)
    }
  end

  private

  def pipeline_summary(pipeline)
    connection = connections[pipeline.id]
    {
      id: pipeline.id, name: pipeline.name, tickets_count: totals[pipeline.id].to_i,
      source: connection && { id: connection.id, provider: connection.provider, name: connection.name, last_synced_at: connection.last_synced_at,
                              last_error: connection.last_error }
    }
  end

  def connections
    @connections ||= account.ticket_source_connections.index_by(&:pipeline_id)
  end

  def totals
    @totals ||= account.tickets.group(:pipeline_id).count
  end

  def stages_with_tickets(pipeline)
    counts = pipeline.tickets.group(:stage_id).count
    pipeline.stages.map do |stage|
      tickets = stage.tickets.includes(:assignee, external_link: :connection).order(updated_at: :desc).limit(TICKETS_PER_STAGE)
      { id: stage.id, name: stage.name, color: stage.color, stage_type: stage.stage_type, count: counts[stage.id].to_i,
        tickets: tickets.map { |ticket| ticket_data(ticket) } }
    end
  end

  def ticket_data(ticket)
    link = ticket.external_link
    {
      id: ticket.id, title: ticket.title, sla_status: ticket.sla_status, updated_at: ticket.updated_at.to_i, created_at: ticket.created_at.to_i,
      assignee: ticket.assignee&.name || link&.external_data&.dig('assignee', 'name'),
      external: link && { provider: link.connection.provider, key: link.external_key, url: link.external_url }
    }
  end
end
