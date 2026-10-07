class SeedCallEmotionAnalysisFeature < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:llm_providers) && table_exists?(:llm_feature_models)

    execute(<<~SQL.squish)
      INSERT INTO llm_feature_models (feature_key, llm_provider_id, model, created_at, updated_at)
      SELECT 'call_emotion_analysis',
             p.id,
             CASE
               WHEN p.provider_type = 'openrouter' AND POSITION('/' IN COALESCE(m.model, 'gpt-4.1-mini')) = 0
                 THEN 'openai/' || COALESCE(m.model, 'gpt-4.1-mini')
               ELSE COALESCE(m.model, 'gpt-4.1-mini')
             END,
             NOW(),
             NOW()
      FROM (SELECT id, provider_type FROM llm_providers ORDER BY id LIMIT 1) p
      LEFT JOIN llm_feature_models m ON m.feature_key = 'conversation_analysis'
      WHERE NOT EXISTS (SELECT 1 FROM llm_feature_models WHERE feature_key = 'call_emotion_analysis')
    SQL
  end

  def down
    return unless table_exists?(:llm_feature_models)

    execute("DELETE FROM llm_feature_models WHERE feature_key = 'call_emotion_analysis'")
  end
end
