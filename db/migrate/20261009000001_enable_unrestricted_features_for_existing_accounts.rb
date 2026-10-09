class EnableUnrestrictedFeaturesForExistingAccounts < ActiveRecord::Migration[7.2]
  FEATURES = YAML.safe_load(Rails.root.join('config/features.yml').read)
                 .reject { |feature| feature['chatwoot_internal'] || feature['deprecated'] || feature['tenant_gated'] }
                 .pluck('name')
                 .freeze

  def up
    Account.find_each(batch_size: 100) do |account|
      account.enable_features(*FEATURES)
      account.save!
    end
  end
end
