module Llm::FeatureRouter
  class UnknownFeatureError < StandardError; end

  class << self
    def resolve(feature:, account:)
      feature_key = feature.to_s
      unless Llm::Features.feature?(feature_key)
        error = UnknownFeatureError.new("Unknown LLM feature: #{feature_key}")
        Llm::AlertRecorder.record(account: account, error: error, feature: feature_key)
        raise error
      end

      feature_model = LlmFeatureModel.includes(:llm_provider).find_by(feature_key: feature_key)
      if feature_model.blank?
        error = CustomExceptions::Llm::FeatureNotConfigured.new(feature: feature_key)
        Llm::AlertRecorder.record(account: account, error: error, feature: feature_key)
        raise error
      end

      provider_type = feature_model.llm_provider.provider_type
      account_provider = account&.account_llm_providers&.find_by(provider_type: provider_type)
      if account_provider.blank?
        error = CustomExceptions::Llm::TenantProviderNotConfigured.new(feature: feature_key, provider: provider_type)
        Llm::AlertRecorder.record(account: account, error: error, feature: feature_key, provider: provider_type)
        raise error
      end

      {
        feature: feature_key,
        provider: provider_type.to_sym,
        model: feature_model.model,
        params: feature_model.request_params,
        context: Llm::Config.context_for(provider_type: provider_type, account_provider: account_provider)
      }
    rescue CustomExceptions::Llm::FeatureNotConfigured
      raise
    rescue StandardError => e
      Llm::AlertRecorder.record(account: account, error: e, feature: feature_key)
      raise
    end
  end
end
