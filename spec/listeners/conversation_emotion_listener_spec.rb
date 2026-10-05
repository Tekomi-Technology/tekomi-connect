require 'rails_helper'

RSpec.describe ConversationEmotionListener do
  let(:conversation) { create(:conversation, status: :resolved) }

  it 'enqueues the exact message snapshot carried by the resolve event' do
    event = Events::Base.new(
      Events::Types::CONVERSATION_RESOLVED,
      Time.current,
      conversation: conversation,
      resolved_message_id: 123
    )

    expect do
      described_class.instance.conversation_resolved(event)
    end.to have_enqueued_job(ConversationEmotionAnalysisJob).with(conversation.id, 123, event.timestamp)
  end

  it 'does not enqueue when the conversation has no public messages' do
    event = Events::Base.new(
      Events::Types::CONVERSATION_RESOLVED,
      Time.current,
      conversation: conversation,
      resolved_message_id: nil
    )

    expect do
      described_class.instance.conversation_resolved(event)
    end.not_to have_enqueued_job(ConversationEmotionAnalysisJob)
  end
end
