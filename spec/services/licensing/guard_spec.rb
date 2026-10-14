require 'rails_helper'

RSpec.describe Licensing::Guard do
  let(:account) { create(:account) }
  let(:guard) { described_class.new(account.reload) }

  context 'without a license' do
    it 'allows everything' do
      expect(guard.check!(:send_message)).to be(true)
      expect(guard.allowed?(:start_call)).to be(true)
    end
  end

  context 'with a message quota' do
    before { create(:account_license, account: account, quotas: { 'messages' => 2 }) }

    it 'blocks once the quota is used up' do
      Licensing::Usage.record!(account.reload, :messages, 2)
      expect { guard.check!(:send_message) }.to raise_error(CustomExceptions::License::QuotaExceeded)
    end

    it 'allows while under quota' do
      Licensing::Usage.record!(account.reload, :messages, 1)
      expect(guard.allowed?(:send_message)).to be(true)
    end

    it 'allows overage when the policy is allow' do
      account.account_license.update!(overage_policy: 'allow')
      Licensing::Usage.record!(account.reload, :messages, 5)
      expect(guard.allowed?(:send_message)).to be(true)
    end

    it 'only logs in shadow mode' do
      account.account_license.update!(enforce: false)
      Licensing::Usage.record!(account.reload, :messages, 5)
      expect(guard.check!(:send_message)).to be(true)
    end
  end

  context 'when the license is restricted' do
    before { create(:account_license, account: account, expires_at: 10.days.ago, grace_days: 1) }

    it 'blocks sending and calling' do
      expect { guard.check!(:send_message) }.to raise_error(CustomExceptions::License::Restricted)
      expect { guard.check!(:start_call) }.to raise_error(CustomExceptions::License::Restricted)
    end
  end

  context 'when the license is suspended' do
    before { create(:account_license, account: account, suspended: true) }

    it 'blocks everything' do
      expect { guard.check!(:create_inbox, channel_type: 'Channel::Email') }.to raise_error(CustomExceptions::License::Suspended)
    end
  end

  context 'with per-channel inbox limits' do
    before { create(:account_license, account: account, quotas: { 'inboxes_by_channel' => { 'web_widget' => 1, 'email' => 0 } }) }

    it 'blocks a channel capped at zero' do
      expect { guard.check!(:create_inbox, channel_type: 'Channel::Email') }.to raise_error(CustomExceptions::License::FeatureNotIncluded)
    end

    it 'blocks past the per-channel count' do
      create(:inbox, account: account)
      expect { guard.check!(:create_inbox, channel_type: 'Channel::WebWidget') }.to raise_error(CustomExceptions::License::FeatureNotIncluded)
    end

    it 'ignores channels without a limit' do
      expect(guard.allowed?(:create_inbox, channel_type: 'Channel::Telegram')).to be(true)
    end
  end
end
