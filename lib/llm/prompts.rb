module Llm::Prompts
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('prompts').freeze

  class << self
    def keys = CONFIG.keys
    def key?(key) = CONFIG.key?(key.to_s)
    def grouped = keys.group_by { |key| CONFIG.dig(key, 'group') }
    def default_body(key) = Rails.root.join(CONFIG.fetch(key.to_s).fetch('path')).read
    def body(key) = LlmPromptTemplate.find_by(key: key.to_s)&.body || default_body(key)
  end
end
