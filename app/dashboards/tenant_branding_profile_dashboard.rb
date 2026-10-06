require 'administrate/base_dashboard'

class TenantBrandingProfileDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo,
    subdomain: Field::String,
    brand_name: Field::String,
    tagline: Field::String,
    primary_color: ColorField.with_options(
      palette: %w[#00789B #2781F6 #1F4FA3 #0D9488 #16A34A #D97706 #EA580C #E11D48 #DC2626 #DB2777 #7C3AED #475569]
    ),
    # Blank defaults match the dashboard's built-in dark sidebar (solid-3 / slate-12 dark tokens).
    sidebar_color: ColorField.with_options(
      palette: %w[#0E2749 #10233F #1E293B #18181B #312E81 #4C1D95 #0F3D3E #14532D #4C0519 #7F1D1D #F8FAFC #FFFFFF],
      default_color: '#0E2749'
    ),
    sidebar_text_color: ColorField.with_options(
      palette: %w[#FFFFFF #EDEEF0 #CBD5E1 #FDE68A #BAE6FD #94A3B8 #475569 #1E293B #0F172A #000000],
      default_color: '#EDEEF0',
      contrast_with: :sidebar_color,
      preview: true
    ),
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
    id account subdomain brand_name tagline primary_color sidebar_color sidebar_text_color origin_ip enabled provisioning_status
    cloudflare_dns_record_id provisioning_error provisioned_at logo logo_dark favicon created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    account subdomain brand_name tagline primary_color sidebar_color sidebar_text_color origin_ip enabled logo logo_dark favicon
  ].freeze

  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(provisioning_status: 'active') },
    failed: ->(resources) { resources.where(provisioning_status: 'failed') },
    enabled: ->(resources) { resources.where(enabled: true) }
  }.freeze

  def display_resource(profile)
    "#{profile.hostname} → ##{profile.account_id} #{profile.account.name}"
  end
end
