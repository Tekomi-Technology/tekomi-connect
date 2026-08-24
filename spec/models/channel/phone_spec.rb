require 'rails_helper'

RSpec.describe Channel::Phone do
  subject(:channel) { build(:channel_phone) }

  it 'accepts secure WebSocket and STUN endpoints' do
    expect(channel).to be_valid
  end

  it 'rejects an insecure WebSocket endpoint' do
    channel.wss_url = 'ws://pbx.example.com:5066'

    expect(channel).not_to be_valid
    expect(channel.errors[:wss_url]).to be_present
  end

  it 'requires a shared secret for TURN endpoints' do
    channel.ice_servers = [{ 'urls' => ['turn:turn.example.com:3478'] }]

    expect(channel).not_to be_valid
    expect(channel.errors[:turn_shared_secret]).to be_present

    channel.turn_shared_secret = 'coturn-secret'

    expect(channel).to be_valid
  end

  it 'rejects invalid ICE endpoint schemes' do
    channel.ice_servers = [{ 'urls' => ['https://turn.example.com'] }]

    expect(channel).not_to be_valid
    expect(channel.errors[:ice_servers]).to be_present
  end
end
