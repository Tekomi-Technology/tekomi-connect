class TenantBranding::ProvisionDnsJob < ApplicationJob
  queue_as :default

  retry_on TenantBranding::ProvisionDnsService::ProvisioningError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(profile_id)
    profile = TenantBrandingProfile.find(profile_id)
    return unless profile.enabled?

    profile.update_columns(provisioning_status: 'provisioning', provisioning_error: nil, updated_at: Time.current)
    TenantBranding::ProvisionDnsService.new(profile: profile).perform
  rescue StandardError => e
    profile&.update_columns(provisioning_status: 'failed', provisioning_error: e.message.truncate(1_000), updated_at: Time.current)
    raise
  end
end
