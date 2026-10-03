## Pipelines, stages and saved views are shared by deals and tickets, so they stay
## available as long as either CRM feature is enabled for the account.
module CrmFeatureConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_crm_enabled
  end

  private

  def ensure_crm_enabled
    return if Current.account.feature_enabled?('crm_deals')
    return if Current.account.feature_enabled?('crm_tickets')

    raise Pundit::NotAuthorizedError
  end
end
