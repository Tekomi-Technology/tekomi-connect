# == Schema Information
#
# Table name: phone_extensions
#
#  id           :bigint           not null, primary key
#  enabled      :boolean          default(TRUE), not null
#  sip_password :text             not null
#  sip_username :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer          not null
#  inbox_id     :integer          not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_phone_extensions_on_account_id                 (account_id)
#  index_phone_extensions_on_inbox_id_and_sip_username  (inbox_id,sip_username) UNIQUE
#  index_phone_extensions_on_inbox_id_and_user_id       (inbox_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
