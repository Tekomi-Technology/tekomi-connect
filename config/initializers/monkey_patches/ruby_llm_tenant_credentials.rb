# ai-agents 0.12 creates RubyLLM::Chat directly and cannot accept a RubyLLM context.
# Resolve API keys from isolated execution state while an account-scoped agent run is active.
module RubyLlmTenantCredentials
  PROVIDER_TYPES = %w[openai openrouter deepseek anthropic gemini mistral xai ollama].freeze

  PROVIDER_TYPES.each do |provider_type|
    define_method("#{provider_type}_api_key") do
      Llm::Config.tenant_api_key(provider_type) || super()
    end
  end
end

RubyLLM::Configuration.prepend(RubyLlmTenantCredentials)
