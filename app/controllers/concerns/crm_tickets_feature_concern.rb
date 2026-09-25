module CrmTicketsFeatureConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_crm_tickets_enabled
  end

  private

  def ensure_crm_tickets_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_tickets')
  end
end
