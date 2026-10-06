require 'administrate/base_dashboard'

class TenantBrandingProfileDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo,
    subdomain: Field::String,
    brand_name: Field::String,
    tagline: Field::String,
    primary_color: Field::String,
    origin_ip: Field::String,
    enabled: Field::Boolean,
    provisioning_status: Field::String,
    cloudflare_dns_record_id: Field::String,
    provisioning_error: Field::Text,
    provisioned_at: Field::DateTime,
    logo: Field::ActiveStorage,
    logo_dark: Field::ActiveStorage,
    favicon: Field::ActiveStorage,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[account subdomain brand_name origin_ip provisioning_status enabled].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id account subdomain brand_name tagline primary_color origin_ip enabled provisioning_status
    cloudflare_dns_record_id provisioning_error provisioned_at logo logo_dark favicon created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[account subdomain brand_name tagline primary_color origin_ip enabled logo logo_dark favicon].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(provisioning_status: 'active') },
    failed: ->(resources) { resources.where(provisioning_status: 'failed') },
    enabled: ->(resources) { resources.where(enabled: true) }
  }.freeze

  def display_resource(profile)
    "#{profile.hostname} → ##{profile.account_id} #{profile.account.name}"
  end
end
