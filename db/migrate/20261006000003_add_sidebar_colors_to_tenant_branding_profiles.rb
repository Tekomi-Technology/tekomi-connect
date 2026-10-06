class AddSidebarColorsToTenantBrandingProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :tenant_branding_profiles, :sidebar_color, :string
    add_column :tenant_branding_profiles, :sidebar_text_color, :string
  end
end
