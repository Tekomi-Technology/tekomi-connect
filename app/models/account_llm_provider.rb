class AccountLlmProvider < ApplicationRecord
  encrypts :api_key

  belongs_to :account

  validates :provider_type, presence: true, inclusion: { in: LlmProvider::PROVIDER_TYPES }, uniqueness: { scope: :account_id }
  validates :api_key, presence: true

  def masked_api_key
    "••••#{api_key.last(4)}" if api_key.present?
  end
end
