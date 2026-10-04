class TeamMemberPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator? || @account_user.supervisor?
  end

  def destroy?
    @account_user.administrator? || @account_user.supervisor?
  end

  def update?
    @account_user.administrator? || @account_user.supervisor?
  end
end
