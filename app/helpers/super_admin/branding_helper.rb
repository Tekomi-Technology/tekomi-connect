module SuperAdmin::BrandingHelper
  def application_title
    GlobalConfigService.load('INSTALLATION_NAME', 'Chatwoot')
  end
end
