require 'rails_helper'

RSpec.describe Crm::Perfex::Mappers::TicketMessageFormatter do
  describe '.transcript_text' do
    context 'when the conversation has no transcriptable messages' do
      it 'returns the no_message translation' do
        conversation = create(:conversation)

        expect(described_class.transcript_text(conversation)).to eq(I18n.t('crm.no_message'))
      end
    end

    context 'when the conversation has public messages' do
      it 'includes the message content in the formatted output' do
        conversation = create(:conversation)
        create(:message, conversation: conversation, content: 'Hello there', private: false)

        text = described_class.transcript_text(conversation)

        expect(text).to include('Hello there')
      end
    end

    context 'when a message has no content' do
      it 'falls back to the no_content translation' do
        conversation = create(:conversation)
        create(:message, conversation: conversation, content: nil, private: false, message_type: :outgoing)

        text = described_class.transcript_text(conversation)

        expect(text).to include(I18n.t('crm.no_content'))
      end
    end
  end
end
