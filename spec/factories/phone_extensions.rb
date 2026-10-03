FactoryBot.define do
  factory :phone_extension do
    account
    inbox { create(:channel_phone, account: account).inbox }
    user { create(:user, account: account) }
    sequence(:sip_username) { |number| "agent#{number}" }
    sip_password { 'secret-password' }
    enabled { true }

    before(:validation) do |extension|
      extension.account = extension.inbox.account
      create(:inbox_member, inbox: extension.inbox, user: extension.user) unless extension.inbox.members.exists?(extension.user.id)
    end
  end
end
