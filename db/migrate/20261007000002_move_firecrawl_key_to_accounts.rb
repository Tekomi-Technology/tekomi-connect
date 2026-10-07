class MoveFirecrawlKeyToAccounts < ActiveRecord::Migration[7.2]
  class MigrationAccountLlmProvider < ApplicationRecord
    self.table_name = 'account_llm_providers'
    encrypts :api_key
  end

  def up
    api_key = InstallationConfig.find_by(name: 'TEKOMI_FIRECRAWL_API_KEY')&.value.presence

    if api_key.present?
      raise 'ACTIVE_RECORD_ENCRYPTION_* must be configured before migrating the FireCrawl API key' unless Chatwoot.encryption_configured?

      account_ids_with_ai_keys.each do |account_id|
        MigrationAccountLlmProvider.create!(account_id: account_id, provider_type: 'firecrawl', api_key: api_key)
      end
    end

    InstallationConfig.where(name: 'TEKOMI_FIRECRAWL_API_KEY').destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def account_ids_with_ai_keys
    select_values("SELECT DISTINCT account_id FROM account_llm_providers WHERE provider_type <> 'firecrawl'")
  end
end
