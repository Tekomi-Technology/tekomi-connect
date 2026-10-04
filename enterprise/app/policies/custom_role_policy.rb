class CustomRolePolicy < ApplicationPolicy
  # Supervisors read the list so the Agents page can name each agent's custom role.
  def index?
    @account_user.administrator? || @account_user.supervisor?
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
