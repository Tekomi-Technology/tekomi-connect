module Llm::ModelCatalog
  class << self
    def grouped_by_provider
      @grouped_by_provider ||= JSON.parse(Rails.root.join('config/llm_models.json').read)
                                   .select { |model| Llm::Providers.type?(model['provider']) }
                                   .group_by { |model| model['provider'] }
                                   .transform_values { |models| models.map { |model| model['id'] }.uniq.sort }
    end
  end
end
