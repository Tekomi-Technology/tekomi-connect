class Deals::MoveService
  MIN_GAP = 1e-6

  pattr_initialize [:deal!, :stage!, :after_deal]

  def perform
    Deal.transaction do
      position = position_between(*neighbour_positions)
      if position.nil?
        renumber_stage
        position = position_between(*neighbour_positions)
      end
      deal.update!(stage: stage, position: position)
    end
    deal
  end

  private

  def neighbour_positions
    siblings = stage.deals.where.not(id: deal.id)
    previous_position = after_deal&.position
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
    Deal.connection.execute(Deal.sanitize_sql_array([<<~SQL.squish, stage.id]))
      UPDATE deals SET position = ranked.row_number
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) AS row_number FROM deals WHERE stage_id = ?) ranked
      WHERE deals.id = ranked.id
    SQL
  end
end
