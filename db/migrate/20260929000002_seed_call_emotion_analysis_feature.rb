class SeedCallEmotionAnalysisFeature < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:llm_providers) && table_exists?(:llm_feature_models)
    return if execute("SELECT 1 FROM llm_feature_models WHERE feature_key = 'call_emotion_analysis'").any?

    provider = LlmProvider.order(:id).first
    return unless provider

    model = LlmFeatureModel.find_by(feature_key: 'conversation_analysis')&.model.presence || 'gpt-4.1-mini'
    model = "openai/#{model}" if provider.provider_type == 'openrouter' && !model.include?('/')

    LlmFeatureModel.create!(feature_key: 'call_emotion_analysis', llm_provider: provider, model: model)
  end

  def down
    return unless table_exists?(:llm_feature_models)

    execute("DELETE FROM llm_feature_models WHERE feature_key = 'call_emotion_analysis'")
  end
end
