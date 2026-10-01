class AddProxyEnabledToChannelZaloPersonal < ActiveRecord::Migration[7.2]
  def up
    add_column :channel_zalo_personal, :proxy_enabled, :boolean, default: true, null: false

    # This column replaces the ZALO_PROXY_ENABLED env switch; carry an existing "off" over so
    # deploying does not route every inbox back through the proxy.
    proxy_disabled = %w[0 false no off].include?(ENV.fetch('ZALO_PROXY_ENABLED', '').strip.downcase)
    execute('UPDATE channel_zalo_personal SET proxy_enabled = FALSE') if proxy_disabled
  end

  def down
    remove_column :channel_zalo_personal, :proxy_enabled
  end
end
