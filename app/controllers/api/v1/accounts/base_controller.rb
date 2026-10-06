class Api::V1::Accounts::BaseController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper
  before_action :current_account
  before_action :enforce_tenant_branding_account
  before_action :validate_token_api_access, if: :authenticate_by_access_token?
  around_action :switch_locale_using_account_locale

  private

  def enforce_tenant_branding_account
    profile = TenantBranding::ProfileResolver.resolve(request.host)
    return unless profile
    return if profile.enabled? && Current.account&.id == profile.account_id

    render json: { error: 'This hostname cannot access the requested account' }, status: :forbidden
  end

  def validate_token_api_access
    return if Current.account.api_and_webhooks_enabled?

    render json: { error: 'API access is not enabled for this account' }, status: :forbidden
  end
end
