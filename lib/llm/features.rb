module Llm::Features
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('features').freeze

  class << self
    def keys = CONFIG.keys
    def feature?(feature_key) = CONFIG.key?(feature_key.to_s)
    def group(feature_key) = CONFIG.fetch(feature_key.to_s).fetch('group')
    def suggested_model(feature_key) = CONFIG.fetch(feature_key.to_s)['suggested_model']
    def fixed?(feature_key) = CONFIG.fetch(feature_key.to_s).key?('model')
    def configurable_keys = keys.reject { |feature_key| fixed?(feature_key) }

    def fixed_route(feature_key)
      config = CONFIG.fetch(feature_key.to_s)
      { provider_type: config.fetch('provider_type'), model: config.fetch('model') }
    end
  end
end
