class EnableTenantGatedFeaturesForExistingAccounts < ActiveRecord::Migration[7.2]
  FEATURES = %w[
    channel_zalo_oa
    channel_zalo_personal
    channel_phone
    crm_perfex_sync
    callbot_integration
    call_transcription
    call_emotion_analysis
    conversation_emotion_analysis
    conversation_analysis
  ].freeze

  def up
    Account.find_each(batch_size: 100) { |account| account.enable_features!(*FEATURES) }
  end

  def down
    Account.find_each(batch_size: 100) { |account| account.disable_features!(*FEATURES) }
  end
end
