class TeamMonitoringPolicy < ApplicationPolicy
  def view?
    @account_user.administrator? || @account_user.supervisor?
  end
end
