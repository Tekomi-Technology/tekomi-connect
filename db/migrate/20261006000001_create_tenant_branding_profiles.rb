class CreateTenantBrandingProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :tenant_branding_profiles do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :subdomain, null: false
      t.string :brand_name, null: false
      t.string :tagline
      t.string :primary_color, null: false, default: '#00789B'
      t.string :origin_ip, null: false
      t.boolean :enabled, null: false, default: true
      t.string :provisioning_status, null: false, default: 'pending'
      t.string :cloudflare_dns_record_id
      t.text :provisioning_error
      t.datetime :provisioned_at
      t.timestamps
    end

    add_index :tenant_branding_profiles, 'LOWER(subdomain)', unique: true,
              name: 'index_tenant_branding_profiles_on_lower_subdomain'
    add_index :tenant_branding_profiles, :provisioning_status
  end
end
