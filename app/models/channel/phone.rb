class Channel::Phone < ApplicationRecord
  include Channelable

  self.table_name = 'channel_phone'

  EDITABLE_ATTRS = [:wss_url, :sip_domain, :sip_username, :sip_password, :stun_url].freeze

  encrypts :sip_password if Chatwoot.encryption_configured?

  validates :wss_url, presence: true, format: { with: %r{\Awss://[^\s]+\z}, message: 'must be a secure WebSocket URL' }
  validates :sip_domain, :sip_username, :sip_password, presence: true
  validates :sip_username, uniqueness: { scope: [:account_id, :sip_domain] }
  validates :stun_url, format: { with: %r{\Astuns?:[^\s]+\z}, allow_blank: true }

  def name
    'Phone'
  end
end

Channel::Phone.prepend_mod_with('Channel::Phone')
