require 'rails_helper'

RSpec.describe ConversationEmotionAnalysisJob do
  let(:conversation) { create(:conversation, status: :resolved) }
  let!(:first_message) do
    create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox, content: 'Tôi cần hỗ trợ')
  end
  let(:analysis_result) do
    {
      'label' => 'trung tính',
      'confidence' => 0.9,
      'probabilities' => { 'trung tính' => 0.9 },
      'reason' => 'Khách hàng trao đổi bình thường.',
      'model' => 'typesafe/jev-1.13',
      'provider' => 'openrouter'
    }
  end
  let(:service) { instance_double(Phone::JevEmotionAnalysisService, perform: analysis_result) }

  before do
    allow(Phone::JevEmotionAnalysisService).to receive(:new).and_return(service)
  end

  it 'analyzes a resolved conversation once for the same message snapshot' do
    described_class.new.perform(conversation.id, first_message.id, Time.current)
    described_class.new.perform(conversation.id, first_message.id, Time.current)

    report = ConversationEmotionReport.find_by!(conversation: conversation)
    expect(report).to have_attributes(status: 'completed', analyzed_through_message_id: first_message.id)
    expect(service).to have_received(:perform).once
  end

  it 'reanalyzes the same report after the reopened conversation receives a new message' do
    described_class.new.perform(conversation.id, first_message.id, Time.current)
    new_message = create(
      :message,
      conversation: conversation,
      account: conversation.account,
      inbox: conversation.inbox,
      content: 'Tôi vẫn chưa được xử lý'
    )

    described_class.new.perform(conversation.id, new_message.id, Time.current)

    expect(ConversationEmotionReport.where(conversation: conversation).count).to eq(1)
    expect(conversation.emotion_report.reload.analyzed_through_message_id).to eq(new_message.id)
    expect(service).to have_received(:perform).twice
  end

  it 'does not let an older job overwrite a newer processing snapshot' do
    report = ConversationEmotionReport.create!(
      conversation: conversation,
      account: conversation.account,
      inbox: conversation.inbox,
      contact: conversation.contact,
      status: 'processing',
      processing_message_id: first_message.id + 1
    )

    described_class.new.send(:persist_result, report, first_message.id, analysis_result)

    expect(report.reload).to have_attributes(status: 'processing', processing_message_id: first_message.id + 1, emotion: nil)
  end

  it 'does not analyze phone inbox conversations' do
    phone_channel = create(:channel_phone, account: conversation.account)
    phone_conversation = create(:conversation, account: conversation.account, inbox: phone_channel.inbox, status: :resolved)
    phone_message = create(
      :message,
      conversation: phone_conversation,
      account: phone_conversation.account,
      inbox: phone_conversation.inbox,
      content: 'Cuoc goi da ket thuc'
    )

    described_class.new.perform(phone_conversation.id, phone_message.id, Time.current)

    expect(ConversationEmotionReport.where(conversation: phone_conversation)).not_to exist
    expect(service).not_to have_received(:perform)
  end
end
