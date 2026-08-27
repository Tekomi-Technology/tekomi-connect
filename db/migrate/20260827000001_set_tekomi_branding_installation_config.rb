class SetTekomiBrandingInstallationConfig < ActiveRecord::Migration[7.1]
  def up
    # INSTALLATION_NAME/BRAND_NAME/etc are seeded once from config/installation_config.yml
    # and ConfigLoader only creates missing configs on subsequent seeds — it never overwrites
    # existing rows. Editing the yml alone does nothing for installs that already have these
    # rows, so force the branding values here so it lands automatically on every deploy.
    {
      'INSTALLATION_NAME' => 'Tekomi',
      'BRAND_NAME' => 'Tekomi',
    }.each do |name, value|
      InstallationConfig.find_by(name: name)&.update!(value: value)
    end

    %w[BRAND_URL WIDGET_BRAND_URL TERMS_URL PRIVACY_URL].each do |name|
      InstallationConfig.find_by(name: name)&.update!(value: nil)
    end

    GlobalConfig.clear_cache
  end
end
