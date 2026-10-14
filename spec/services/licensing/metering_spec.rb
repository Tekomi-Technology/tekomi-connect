require 'rails_helper'

RSpec.describe 'License metering' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe 'messages' do
    before { create(:account_license, account: account, quotas: { 'messages' => 2 }) }

    it 'counts public outgoing messages only' do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, private: true)

      expect(Licensing::Usage.used(account.reload, :messages)).to eq(1)
    end

    it 'rejects sends beyond the quota when enforced' do
      2.times { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing) }
      message = build(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing)

      expect(message).not_to be_valid
      expect(message.errors[:base].join).to match(/quota/i)
    end

    it 'still accepts incoming messages at the limit' do
      2.times { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing) }

      expect(build(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)).to be_valid
    end
  end

  describe 'calls' do
    before { create(:account_license, account: account, quotas: { 'calls' => 5, 'call_minutes' => 10 }) }

    it 'counts the call on create and rounds minutes up once, at completion' do
      call = create(:call, conversation: conversation)
      call.update!(status: 'completed', duration_seconds: 61)
      call.update!(duration_seconds: 200)

      expect(Licensing::Usage.used(account.reload, :calls)).to eq(1)
      expect(Licensing::Usage.used(account, :call_minutes)).to eq(2)
    end
  end
end
