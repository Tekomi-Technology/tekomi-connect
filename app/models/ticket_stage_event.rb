class TicketStageEvent < ApplicationRecord
  belongs_to :ticket
  belongs_to :pipeline_stage

  scope :open, -> { where(exited_at: nil) }

  before_create :apply_stage_sla
  after_create_commit :sync_ticket_sla_status
  after_update_commit :sync_ticket_sla_status, if: :saved_change_to_sla_timestamps?

  def sla_status
    return 'no_sla' if due_at.blank?
    return 'breached' if missed_at.present?
    return 'at_risk' if warned_at.present?

    'on_track'
  end

  def push_event_data
    {
      stage_id: pipeline_stage_id,
      entered_at: entered_at.to_i,
      due_at: due_at&.to_i,
      warn_at: warn_at&.to_i,
      warned_at: warned_at&.to_i,
      missed_at: missed_at&.to_i,
      sla_status: sla_status
    }
  end

  private

  # The thresholds are copied onto the event so that editing or deleting the
  # stage SLA later does not change the deadlines of tickets already in flight.
  def apply_stage_sla
    self.entered_at ||= Time.current
    sla = pipeline_stage.ticket_stage_sla
    return if sla.blank?

    self.due_at = entered_at + sla.threshold_minutes.minutes
    self.warn_at = entered_at + (sla.threshold_minutes * sla.warning_threshold_percent / 100.0).minutes
  end

  def saved_change_to_sla_timestamps?
    saved_change_to_warned_at? || saved_change_to_missed_at?
  end

  # update! rather than update_column so the ticket dispatches its update event
  # and the board reflects the new SLA state without a refresh.
  def sync_ticket_sla_status
    ticket.update!(sla_status: sla_status)
  end
end
