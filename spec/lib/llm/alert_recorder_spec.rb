# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::AlertRecorder do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }

  before do
    allow(ActionCableBroadcastJob).to receive(:perform_later)
  end

  it 'classifies quota failures and redacts credentials' do
    described_class.record(
      account: account,
      feature: 'reply',
      provider: 'openrouter',
      error: StandardError.new('HTTP 429: api_key=sk-secret rate limit exceeded')
    )

    alert = account.ai_alerts.last
    expect(alert.category).to eq('quota')
    expect(alert.status_code).to eq(429)
    expect(alert.message).not_to include('sk-secret')
    expect(ActionCableBroadcastJob).to have_received(:perform_later).with(
      [admin.pubsub_token],
      'ai_alert.created',
      hash_including(ai_alert: hash_including(id: alert.id))
    )
  end

  it 'deduplicates the same recent failure and increments occurrences' do
    error = StandardError.new('HTTP 429: rate limit exceeded')

    expect do
      2.times { described_class.record(account: account, feature: 'reply', error: error) }
    end.to change(AiAlert, :count).by(1)

    expect(account.ai_alerts.last.occurrences).to eq(2)
  end
end
