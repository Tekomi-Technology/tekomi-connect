class DeviseOverrides::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  def validate_token
    # @resource will have been set by set_user_by_token concern
    if @resource && tenant_branding_access_allowed?(@resource)
      render 'devise/token', formats: [:json]
    else
      render_validate_token_error
    end
  end


  private

  def tenant_branding_access_allowed?(user)
    profile = TenantBranding::ProfileResolver.resolve(request.host)
    return true unless profile

    profile.enabled? && user.account_users.exists?(account_id: profile.account_id)
  end
end
