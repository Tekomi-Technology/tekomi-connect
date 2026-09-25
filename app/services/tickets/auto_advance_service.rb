## Moves a ticket forward on its own once the stage it sits in has everything it asked for.
## Stages opt in through `auto_advance_fields`; an empty list means the stage always waits
## for a person. Advancing re-runs this service through the ticket's update callback, so a
## ticket that satisfies several stages at once walks through all of them in one go.
class Tickets::AutoAdvanceService
  pattr_initialize [:ticket!]

  def perform
    return if required_fields.blank?
    return unless ticket_satisfies_stage?
    return if next_stage.blank?

    ticket.update!(stage: next_stage, position: position_in_next_stage)
  end

  private

  delegate :stage, to: :ticket

  def required_fields
    stage.auto_advance_fields
  end

  def ticket_satisfies_stage?
    required_fields.all? { |field| ticket.public_send(field).present? }
  end

  def next_stage
    @next_stage ||= stage.next_stage
  end

  # Lands at the bottom of the next column, the same place a ticket created there would go.
  def position_in_next_stage
    (next_stage.tickets.maximum(:position) || 0) + 1
  end
end
