class RemoveVendorReportingConfiguration < ActiveRecord::Migration[7.1]
  VENDOR_CONFIG_KEYS = %w[
    INSTALLATION_IDENTIFIER
    CHATWOOT_INBOX_TOKEN
    CHATWOOT_INBOX_HMAC_KEY
    CHATWOOT_SUPPORT_WEBSITE_TOKEN
    CHATWOOT_SUPPORT_SCRIPT_URL
    CHATWOOT_SUPPORT_IDENTIFIER_HASH
    CLOUD_ANALYTICS_TOKEN
    MARKETING_CONVERSION_TRACKING_CONFIG
    ACCOUNT_SECURITY_NOTIFICATION_WEBHOOK_URL
  ].freeze

  def up
    quoted_keys = VENDOR_CONFIG_KEYS.map { |key| connection.quote(key) }.join(', ')
    execute "DELETE FROM installation_configs WHERE name IN (#{quoted_keys})"
    execute <<~SQL.squish
      UPDATE accounts
      SET internal_attributes = COALESCE(internal_attributes, '{}'::jsonb) - 'marketing_attribution'
      WHERE COALESCE(internal_attributes, '{}'::jsonb) ? 'marketing_attribution'
    SQL
  end

  def down; end
end
