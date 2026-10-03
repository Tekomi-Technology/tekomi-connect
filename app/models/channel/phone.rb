class Channel::Phone < ApplicationRecord
  include Channelable

  self.table_name = 'channel_phone'

  EDITABLE_ATTRS = [
    :wss_url,
    :sip_domain,
    :turn_shared_secret,
    :turn_credential_ttl,
    { ice_servers: [:credential_type, { urls: [] }] }
  ].freeze

  encrypts :sip_password if Chatwoot.encryption_configured?
  encrypts :turn_shared_secret if Chatwoot.encryption_configured?

  validates :wss_url, presence: true, format: { with: %r{\Awss://[^\s]+\z}, message: 'must be a secure WebSocket URL' }
  validates :sip_domain, presence: true
  validates :turn_credential_ttl, numericality: { only_integer: true, greater_than_or_equal_to: 300, less_than_or_equal_to: 86_400 }
  validate :valid_ice_servers
  validate :turn_shared_secret_present

  def name
    'Phone'
  end

  def turn_configured?
    turn_shared_secret.present?
  end

  private

  def valid_ice_servers
    return errors.add(:ice_servers, 'must be an array') unless ice_servers.is_a?(Array)

    valid = ice_servers.all? do |configuration|
      urls = ice_server_urls(configuration)
      configuration.is_a?(Hash) && urls.present? &&
        urls.all? { |url| url.is_a?(String) && url.match?(%r{\A(?:stun|stuns|turn|turns):[^\s]+\z}) }
    end
    errors.add(:ice_servers, 'contains an invalid STUN or TURN URL') unless valid
  end

  def turn_shared_secret_present
    has_turn_server = Array(ice_servers).any? do |configuration|
      ice_server_urls(configuration).any? { |url| url.is_a?(String) && url.start_with?('turn:', 'turns:') }
    end
    errors.add(:turn_shared_secret, 'is required when TURN servers are configured') if has_turn_server && turn_shared_secret.blank?
  end

  def ice_server_urls(configuration)
    return [] unless configuration.is_a?(Hash)

    Array(configuration['urls'] || configuration[:urls])
  end
end

Channel::Phone.prepend_mod_with('Channel::Phone')
