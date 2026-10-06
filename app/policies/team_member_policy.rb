class TeamMemberPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator? || supervises_team?
  end

  def destroy?
    create?
  end

  def update?
    create?
  end

  private

  # @record is the team the members belong to; supervisors only manage their own team.
  def supervises_team?
    @account_user.supervisor? && @record.is_a?(Team) && @record.supervisor_id == @user.id
  end
end
