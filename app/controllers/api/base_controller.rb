class Api::BaseController < ApplicationController
  include AccessTokenAuthHelper
  respond_to :json
  before_action :authenticate_access_token!, if: :authenticate_by_access_token?
  before_action :validate_bot_access_token!, if: :authenticate_by_access_token?
  before_action :authenticate_user!, unless: :authenticate_by_access_token?
  before_action :enforce_tenant_branding_membership, unless: :authenticate_by_access_token?

  private

  def enforce_tenant_branding_membership
    profile = TenantBranding::ProfileResolver.resolve(request.host)
    return unless profile
    return head :not_found unless profile.enabled?
    return if current_user.account_users.exists?(account_id: profile.account_id)

    render json: { error: 'This hostname is restricted to another account' }, status: :forbidden
  end

  def authenticate_by_access_token?
    request.headers[:api_access_token].present? || request.headers[:HTTP_API_ACCESS_TOKEN].present?
  end

  def check_authorization(model = nil)
    model ||= controller_name.classify.constantize

    authorize(model)
  end

  def check_admin_authorization?
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end
end
