class PhoneExtension < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :user

  encrypts :sip_password if Chatwoot.encryption_configured?

  validates :sip_username, :sip_password, presence: true
  validates :user_id, uniqueness: { scope: :inbox_id }
  validates :sip_username, uniqueness: { scope: :inbox_id }
  validate :phone_inbox_belongs_to_account
  validate :user_is_inbox_member

  scope :enabled, -> { where(enabled: true) }

  private

  def phone_inbox_belongs_to_account
    return if inbox&.phone? && inbox.account_id == account_id

    errors.add(:inbox, 'must be a phone inbox in the same account')
  end

  def user_is_inbox_member
    return if inbox&.members&.exists?(id: user_id)

    errors.add(:user, 'must be assigned to the inbox')
  end
end
