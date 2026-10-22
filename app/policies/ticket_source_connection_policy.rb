class TicketSourceConnectionPolicy < ApplicationPolicy
  def manage?
    @account_user.administrator?
  end

  %i[index show create update destroy providers test sync_statuses sync register_webhook unregister_webhook].each do |action|
    define_method(:"#{action}?") { manage? }
  end
end

TicketSourceConnectionPolicy.prepend_mod_with('TicketSourceConnectionPolicy')
