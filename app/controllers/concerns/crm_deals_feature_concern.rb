module CrmDealsFeatureConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_crm_deals_enabled
  end

  private

  def ensure_crm_deals_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_deals')
  end
end
