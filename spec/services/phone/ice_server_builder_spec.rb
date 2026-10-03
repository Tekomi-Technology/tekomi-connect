require 'rails_helper'

RSpec.describe Phone::IceServerBuilder do
  subject(:ice_servers) { described_class.new(channel: channel, user: user, current_time: current_time).call }

  let(:user) { create(:user) }
  let(:current_time) { Time.zone.at(1_700_000_000) }
  let(:channel) do
    build(
      :channel_phone,
      ice_servers: [
        { 'urls' => ['stun:stun.example.com:3478'] },
        { 'urls' => ['turn:turn.example.com:3478?transport=udp', 'turns:turn.example.com:5349'] }
      ],
      turn_shared_secret: 'coturn-secret',
      turn_credential_ttl: 3600
    )
  end

  it 'keeps STUN public and generates time-limited Coturn REST credentials for TURN' do
    expires_at = 1_700_003_600
    username = "#{expires_at}:#{user.id}"
    credential = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', 'coturn-secret', username))

    expect(ice_servers).to eq(
      [
        { urls: ['stun:stun.example.com:3478'] },
        {
          urls: ['turn:turn.example.com:3478?transport=udp', 'turns:turn.example.com:5349'],
          username: username,
          credential: credential
        }
      ]
    )
  end
end
