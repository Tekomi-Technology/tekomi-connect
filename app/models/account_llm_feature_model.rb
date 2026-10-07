class AccountLlmFeatureModel < ApplicationRecord
  REASONING_OPTIONS = %w[off low medium high].freeze

  belongs_to :account

  before_validation do
    self.model = model.to_s.strip.presence
    self.reasoning = reasoning.presence
  end

  validates :feature_key, presence: true, inclusion: { in: ->(_record) { Llm::Features.keys } }, uniqueness: { scope: :account_id }
  validates :provider_type, presence: true, inclusion: { in: ->(_record) { Llm::Providers.types } }
  validates :model, presence: true
  validates :reasoning, inclusion: { in: REASONING_OPTIONS }, allow_nil: true
  validate :reasoning_supported_by_provider
  validate { errors.add(:params, :invalid) unless params.is_a?(Hash) }

  def request_params
    reasoning_params.deep_merge(params.deep_symbolize_keys)
  end

  private

  def reasoning_params
    case reasoning
    when nil then {}
    when 'off' then { reasoning: { enabled: false } }
    else { reasoning: { effort: reasoning } }
    end
  end

  def reasoning_supported_by_provider
    return if reasoning.nil? || (Llm::Providers.type?(provider_type) && Llm::Providers.supports_reasoning?(provider_type))

    errors.add(:reasoning, I18n.t('errors.llm.reasoning_unsupported'))
  end
end
