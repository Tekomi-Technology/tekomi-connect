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

  it 'requires a unique SIP identity per account and domain' do
    existing_channel = create(:channel_phone)
    duplicate = build(
      :channel_phone,
      account: existing_channel.account,
      sip_domain: existing_channel.sip_domain,
      sip_username: existing_channel.sip_username
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:sip_username]).to be_present
  end
end
