class UseJevForCallEmotionAnalysis < ActiveRecord::Migration[7.2]
  def up
    openrouter = LlmProvider.find_by!(provider_type: 'openrouter')
    feature_model = LlmFeatureModel.find_by!(feature_key: 'call_emotion_analysis')
    feature_model.update!(llm_provider: openrouter, model: 'typesafe/jev-1.13', reasoning: nil, params: {})
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'The previous call emotion model and provider were installation-specific'
  end
end
