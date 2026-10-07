module Llm::Services
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('services').freeze

  class << self
    def types = CONFIG.keys
    def type?(service_type) = CONFIG.key?(service_type.to_s)
    def label(service_type) = CONFIG.fetch(service_type.to_s).fetch('label')
  end
end
