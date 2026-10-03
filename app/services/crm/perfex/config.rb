## Central place to read the Perfex connection settings. `GlobalConfigService` checks the
## InstallationConfig row (editable from Super Admin) first and falls back to the ENV var,
## so existing installs keep working until someone fills the value in from the UI.
class Crm::Perfex::Config
  def self.system_url
    GlobalConfigService.load('EXTERNAL_TICKET_SYSTEM_URL', '')
  end

  def self.api_key
    GlobalConfigService.load('EXTERNAL_TICKET_SYSTEM_API_KEY', '')
  end

  def self.department_id
    GlobalConfigService.load('EXTERNAL_TICKET_DEPARTMENT_ID', '')
  end

  def self.configured?
    system_url.present? && api_key.present?
  end
end
