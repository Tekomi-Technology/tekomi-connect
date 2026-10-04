require 'ruby_llm'

module Llm::Config
  VERSION_KEY = 'LLM_PROVIDERS_CONFIG_VERSION'.freeze
  TENANT_CREDENTIALS_KEY = :llm_tenant_provider_credentials

  class << self
    def apply!
      version = $alfred.with { |conn| conn.get(VERSION_KEY) }.to_i
      return if @applied_version == version

      providers = LlmProvider.all.index_by(&:provider_type)
      RubyLLM.configure do |config|
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
        LlmProvider::PROVIDER_TYPES.each { |provider_type| assign_provider(config, provider_type, providers[provider_type]) }
      end
      @applied_version = version
    end

    def bump_version!
      $alfred.with { |conn| conn.incr(VERSION_KEY) }
    end

    def context_for(provider_type:, account_provider:)
      apply!

      RubyLLM.context do |config|
        clear_api_keys(config)
        assign_provider(config, provider_type, account_provider, clear_missing: false)
      end
    end

    def with_account(account, provider_type:)
      previous_credentials = ActiveSupport::IsolatedExecutionState[TENANT_CREDENTIALS_KEY]
      providers = account.account_llm_providers.index_by(&:provider_type).transform_values(&:api_key)
      unless providers.key?(provider_type.to_s)
        raise CustomExceptions::Llm::TenantProviderNotConfigured.new(provider: provider_type)
      end

      ActiveSupport::IsolatedExecutionState[TENANT_CREDENTIALS_KEY] = providers
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[TENANT_CREDENTIALS_KEY] = previous_credentials
    end

    def tenant_api_key(provider_type)
      ActiveSupport::IsolatedExecutionState[TENANT_CREDENTIALS_KEY]&.[](provider_type.to_s)
    end

    def tenant_credentials_active?
      ActiveSupport::IsolatedExecutionState[TENANT_CREDENTIALS_KEY].is_a?(Hash)
    end

    def assign_provider(config, provider_type, provider, clear_missing: true)
      %w[api_key api_base].each do |attribute|
        setter = "#{provider_type}_#{attribute}="
        value = provider.public_send(attribute).presence if provider&.respond_to?(attribute)
        config.public_send(setter, value) if config.respond_to?(setter) && (clear_missing || value)
      end
    end

    def clear_api_keys(config)
      LlmProvider::PROVIDER_TYPES.each do |provider_type|
        setter = "#{provider_type}_api_key="
        config.public_send(setter, nil) if config.respond_to?(setter)
      end
    end

    private :assign_provider, :clear_api_keys
  end
end
