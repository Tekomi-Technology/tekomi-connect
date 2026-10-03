require 'rails_helper'

RSpec.describe Twitter::TweetParserService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_twitter_profile, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:service) { described_class.new(payload: {}) }
  let(:parent_tweet_id) { 'tweet-123' }

  before do
    service.instance_variable_set(:@inbox, inbox)
    service.instance_variable_set(:@contact, contact)
    service.instance_variable_set(:@contact_inbox, contact_inbox)
    allow(service).to receive(:parent_tweet_id).and_return(parent_tweet_id)
    allow(service).to receive(:tweet_data).and_return('source' => 'web')
  end

  describe '#set_conversation' do
    let!(:resolved_conversation) do
      create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                            status: :resolved,
                            additional_attributes: { type: 'tweet', tweet_id: parent_tweet_id, tweet_source: 'web' })
    end

    it 'creates a new conversation after resolve when conversation locking is disabled' do
      inbox.update!(lock_to_single_conversation: false)

      expect { service.send(:set_conversation) }.to change(Conversation, :count).by(1)
      expect(service.instance_variable_get(:@conversation)).not_to eq(resolved_conversation)
    end

    it 'reuses the resolved conversation when conversation locking is enabled' do
      inbox.update!(lock_to_single_conversation: true)

      expect { service.send(:set_conversation) }.not_to change(Conversation, :count)
      expect(service.instance_variable_get(:@conversation)).to eq(resolved_conversation)
    end
  end
end
