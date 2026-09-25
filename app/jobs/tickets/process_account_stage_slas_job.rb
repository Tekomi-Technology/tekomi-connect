class Tickets::ProcessAccountStageSlasJob < ApplicationJob
  queue_as :medium

  def perform(account)
    pending_stage_events(account).find_each do |stage_event|
      Tickets::EvaluateStageSlaService.new(stage_event: stage_event).perform
    end
  end

  private

  # warn_at is always earlier than due_at, so an event that has not reached warn_at
  # cannot need either flag yet. Events already marked as missed are fully flagged.
  def pending_stage_events(account)
    TicketStageEvent.open
                    .where(missed_at: nil)
                    .where(warn_at: ..Time.current)
                    .where(ticket_id: account.tickets.select(:id))
                    .includes(:ticket)
  end
end
