module Llm::Providers
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('providers').freeze

  class << self
    def types = CONFIG.keys
    def type?(provider_type) = CONFIG.key?(provider_type.to_s)
    def label(provider_type) = CONFIG.fetch(provider_type.to_s).fetch('label')
    def requires_api_base?(provider_type) = CONFIG.fetch(provider_type.to_s)['requires_api_base'].present?
    def supports_reasoning?(provider_type) = CONFIG.fetch(provider_type.to_s)['supports_reasoning'].present?
  end
end
