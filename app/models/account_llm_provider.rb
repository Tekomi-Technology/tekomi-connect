class AccountLlmProvider < ApplicationRecord
  encrypts :api_key

  belongs_to :account

  validates :provider_type, presence: true, inclusion: { in: ->(_record) { Llm::Providers.types + Llm::Services.types } },
                            uniqueness: { scope: :account_id }
  validates :api_key, presence: true, unless: :requires_api_base?
  validates :api_base, presence: true, if: :requires_api_base?
  validate :api_base_supported

  def requires_api_base?
    Llm::Providers.type?(provider_type) && Llm::Providers.requires_api_base?(provider_type)
  end

  def masked_api_key
    "••••#{api_key.last(4)}" if api_key.present?
  end

  private

  def api_base_supported
    return if api_base.blank? || RubyLLM.config.respond_to?("#{provider_type}_api_base=")

    errors.add(:api_base, :invalid)
  end
end
