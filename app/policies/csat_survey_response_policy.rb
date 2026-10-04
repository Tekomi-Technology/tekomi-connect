class CsatSurveyResponsePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.supervisor?
  end

  def metrics?
    @account_user.administrator? || @account_user.supervisor?
  end

  def download?
    @account_user.administrator? || @account_user.supervisor?
  end
end

CsatSurveyResponsePolicy.prepend_mod_with('CsatSurveyResponsePolicy')
