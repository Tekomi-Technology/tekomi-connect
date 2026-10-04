class ReportPolicy < ApplicationPolicy
  def view?
    @account_user.administrator? || @account_user.supervisor?
  end
end

ReportPolicy.prepend_mod_with('ReportPolicy')
