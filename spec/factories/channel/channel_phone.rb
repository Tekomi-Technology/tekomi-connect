FactoryBot.define do
  factory :channel_phone, class: 'Channel::Phone' do
    account
    wss_url { 'wss://pbx.example.com:7443' }
    sip_domain { 'pbx.example.com' }
    sequence(:sip_username) { |number| "agent#{number}" }
    sip_password { 'secret-password' }
    stun_url { 'stun:stun.example.com:3478' }

    after(:create) do |channel_phone|
      create(:inbox, channel: channel_phone, account: channel_phone.account)
    end
  end
end
