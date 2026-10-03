class Tickets::MoveService
  MIN_GAP = 1e-6

  pattr_initialize [:ticket!, :stage!, :after_ticket]

  def perform
    Ticket.transaction do
      position = position_between(*neighbour_positions)
      if position.nil?
        renumber_stage
        position = position_between(*neighbour_positions)
      end
      ticket.update!(stage: stage, position: position)
    end
    ticket
  end

  private

  def neighbour_positions
    siblings = stage.tickets.where.not(id: ticket.id)
    previous_position = after_ticket&.position
    next_scope = previous_position ? siblings.where('position > ?', previous_position) : siblings
    [previous_position, next_scope.minimum(:position)]
  end

  def position_between(previous_position, next_position)
    return (next_position || 1) - 1 if previous_position.nil?
    return previous_position + 1 if next_position.nil?
    return if next_position - previous_position < MIN_GAP

    (previous_position + next_position) / 2
  end

  def renumber_stage
    Ticket.connection.execute(Ticket.sanitize_sql_array([<<~SQL.squish, stage.id]))
      UPDATE tickets SET position = ranked.row_number
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) AS row_number FROM tickets WHERE stage_id = ?) ranked
      WHERE tickets.id = ranked.id
    SQL
  end
end
