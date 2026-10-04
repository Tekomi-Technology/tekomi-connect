module Llm::FeatureRouter
  class UnknownFeatureError < StandardError; end

  class << self
    def resolve(feature:, account: nil)
      feature_key = feature.to_s
      raise UnknownFeatureError, "Unknown LLM feature: #{feature_key}" unless Llm::Features.feature?(feature_key)

      feature_model = LlmFeatureModel.includes(:llm_provider).find_by(feature_key: feature_key)
      raise CustomExceptions::Llm::FeatureNotConfigured.new(feature: feature_key) if feature_model.blank?

      provider_type = feature_model.llm_provider.provider_type
      {
        feature: feature_key,
        provider: provider_type.to_sym,
        model: feature_model.model,
        params: feature_model.request_params,
        context: Llm::Config.context_for(provider_type: provider_type, account: account)
      }
    end
  end
end
