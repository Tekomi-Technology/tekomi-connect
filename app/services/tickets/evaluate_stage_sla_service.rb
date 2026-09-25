class Tickets::EvaluateStageSlaService
  pattr_initialize [:stage_event!]

  def perform
    return if stage_event.due_at.blank?

    flag_warning
    flag_missed
  end

  private

  delegate :ticket, to: :stage_event

  def flag_warning
    return if stage_event.warned_at.present?
    return if Time.current < stage_event.warn_at

    stage_event.update!(warned_at: Time.current)
    notify('ticket_sla_warning')
  end

  def flag_missed
    return if stage_event.missed_at.present?
    return if Time.current < stage_event.due_at

    stage_event.update!(missed_at: Time.current)
    notify('ticket_sla_missed')
  end

  def notify(notification_type)
    notify_users.each do |user|
      NotificationBuilder.new(
        notification_type: notification_type,
        user: user,
        account: ticket.account,
        primary_actor: ticket,
        secondary_actor: stage_event
      ).perform
    end
  end

  def notify_users
    ([ticket.assignee] + ticket.account.administrators).compact.uniq
  end
end
