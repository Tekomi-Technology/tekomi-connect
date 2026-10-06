# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAlert, type: :model do
  it 'serializes safe data for realtime delivery' do
    alert = build(:ai_alert, read_at: nil, metadata: { model: 'gpt-test' }, occurrences: 2)

    expect(alert.push_event_data).to include(
      id: nil,
      category: 'quota',
      occurrences: 2,
      read_at: nil,
      metadata: { model: 'gpt-test' }
    )
  end

  it 'requires a supported category' do
    alert = build(:ai_alert, category: 'not-a-category')

    expect(alert).not_to be_valid
    expect(alert.errors[:category]).to be_present
  end
end
