class UseJevForCallEmotionAnalysis < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL.squish)
      UPDATE llm_feature_models
      SET model = 'typesafe/jev-1.13',
          reasoning = NULL,
          params = '{}'::jsonb,
          llm_provider_id = (SELECT id FROM llm_providers WHERE provider_type = 'openrouter' LIMIT 1)
      WHERE feature_key = 'call_emotion_analysis'
        AND EXISTS (SELECT 1 FROM llm_providers WHERE provider_type = 'openrouter')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'The previous call emotion model and provider were installation-specific'
  end
end
