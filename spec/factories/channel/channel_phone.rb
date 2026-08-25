FactoryBot.define do
  factory :channel_phone, class: 'Channel::Phone' do
    account
    wss_url { 'wss://pbx.example.com:7443' }
    sip_domain { 'pbx.example.com' }
    ice_servers { [{ 'urls' => ['stun:stun.example.com:3478'] }] }

    after(:create) do |channel_phone|
      create(:inbox, channel: channel_phone, account: channel_phone.account)
    end
  end
end
