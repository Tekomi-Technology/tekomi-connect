module Enterprise::TicketSourceConnectionPolicy
  def manage?
    @account_user.custom_role&.permissions&.include?('ticket_source_manage') || super
  end
end
