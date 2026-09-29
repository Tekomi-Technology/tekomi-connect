class LlmFeatureModel < ApplicationRecord
  REASONING_OPTIONS = %w[off low medium high].freeze

  belongs_to :llm_provider

  before_validation do
    self.model = model.to_s.strip.presence
    self.reasoning = reasoning.presence
  end

  validates :feature_key, presence: true, uniqueness: true, inclusion: { in: ->(_record) { Llm::Features.keys } }
  validates :model, presence: true
  validates :reasoning, inclusion: { in: REASONING_OPTIONS }, allow_nil: true
  validate :reasoning_supported_by_provider
  validate { errors.add(:params, :invalid) if @params_json_invalid || !params.is_a?(Hash) }

  def params_json
    params.present? ? JSON.pretty_generate(params) : ''
  end

  def params_json=(value)
    @params_json_invalid = false
    self.params = value.blank? ? {} : JSON.parse(value)
  rescue JSON::ParserError
    @params_json_invalid = true
  end

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
    return if reasoning.nil? || llm_provider&.provider_type == 'openrouter'

    errors.add(:reasoning, I18n.t('super_admin.llm_feature_models.reasoning_unsupported'))
  end
end
