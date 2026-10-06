class SuperAdmin::TenantBrandingProfilesController < SuperAdmin::ApplicationController
  def provision
    requested_resource.update_columns(provisioning_status: 'pending', provisioning_error: nil, updated_at: Time.current)
    TenantBranding::ProvisionDnsJob.perform_later(requested_resource.id)
    redirect_to super_admin_tenant_branding_profile_path(requested_resource),
                notice: I18n.t('super_admin.tenant_branding_profiles.provisioning_started')
  end

  def destroy
    redirect_to super_admin_tenant_branding_profile_path(requested_resource),
                alert: I18n.t('super_admin.tenant_branding_profiles.disable_before_removal')
  end
end
