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

      selection = select_model(account, feature_key)
      account_provider = account&.account_llm_providers&.find_by(provider_type: selection[:provider_type])
      if account_provider.blank?
        error = CustomExceptions::Llm::TenantProviderNotConfigured.new(feature: feature_key, provider: selection[:provider_type])
        Llm::AlertRecorder.record(account: account, error: error, feature: feature_key, provider: selection[:provider_type])
        raise error
      end

      {
        feature: feature_key,
        provider: selection[:provider_type].to_sym,
        model: selection[:model],
        params: selection[:params],
        context: Llm::Config.context_for(provider_type: selection[:provider_type], account_provider: account_provider)
      }
    rescue CustomExceptions::Llm::FeatureNotConfigured
      raise
    rescue StandardError => e
      Llm::AlertRecorder.record(account: account, error: e, feature: feature_key)
      raise
    end

    private

    def select_model(account, feature_key)
      override = account&.account_llm_feature_models&.find_by(feature_key: feature_key)
      return { provider_type: override.provider_type, model: override.model, params: override.request_params } if override

      return Llm::Features.fixed_route(feature_key).merge(params: {}) if Llm::Features.fixed?(feature_key)

      provider_type = account&.llm_default_provider_type.presence
      model = account&.llm_default_model.presence
      if provider_type.blank? || model.blank?
        error = CustomExceptions::Llm::FeatureNotConfigured.new(feature: feature_key)
        Llm::AlertRecorder.record(account: account, error: error, feature: feature_key)
        raise error
      end

      { provider_type: provider_type, model: model, params: {} }
    end
  end
end
