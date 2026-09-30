require 'rails_helper'

RSpec.describe 'Phone Calls API', type: :request do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_phone, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, phone_number: '+84342387314') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:phone_call) do
    PhoneCall.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      conversation: conversation,
      pbx_id: 'callytics:1',
      linked_id: 'call-1',
      direction: 'outbound',
      status: 'completed',
      customer_number: '+84342387314',
      from_number: '02899966166',
      to_number: '0342387314',
      duration_seconds: 60,
      hangup_cause: 'normal_clearing',
      started_at: Time.zone.parse('2026-09-11 11:00:00'),
      metadata: metadata
    )
  end
  let(:metadata) do
    {
      'callbot_report' => {
        'campaign_id' => 345,
        'metadata' => { 'vendorCallId' => 'vendor-1' },
        'result' => {
          'outcome' => 'answered',
          'summary' => 'Đã thông báo xong.',
          'analysisStatus' => 'ready',
          'customerIntent' => 'Xác nhận thông tin',
          'customerDisposition' => 'engaged',
          'callback' => { 'status' => 'not_requested' },
          'business' => { 'resolution' => 'notification_delivered', 'failureReason' => nil },
          'captured' => { 'fields' => { 'reference' => 'ABC' }, 'confirmedActions' => [] },
          'actions' => []
        },
        'conversation' => {
          'turns' => [
            { 'speaker' => 'bot', 'text' => 'Xin chào |CHAT</ctl>', 'occurredAt' => nil },
            { 'speaker' => 'user', 'text' => 'Tôi đã hiểu', 'occurredAt' => '2026-09-11T11:00:10Z' }
          ]
        }
      }
    }
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  describe 'GET /api/v1/accounts/:account_id/phone_calls/:id' do
    it 'returns callbot details and a cleaned transcript', :aggregate_failures do
      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'call_id' => 'call-1',
        'campaign_id' => 345,
        'direction' => 'outbound',
        'summary' => 'Đã thông báo xong.',
        'customer_intent' => 'Xác nhận thông tin',
        'captured_fields' => { 'reference' => 'ABC' }
      )
      expect(response.parsed_body['transcript']).to eq([
                                                         { 'speaker' => 'bot', 'text' => 'Xin chào' },
                                                         {
                                                           'speaker' => 'user',
                                                           'text' => 'Tôi đã hiểu',
                                                           'occurred_at' => '2026-09-11T11:00:10Z'
                                                         }
                                                       ])
    end

    it 'does not expose a details payload for a non-callbot phone call' do
      phone_call.update!(metadata: {})

      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'does not accept a recording playback token as dashboard authentication' do
      token = Rails.application.message_verifier('phone_call_recording').generate(
        { phone_call_id: phone_call.id, account_id: account.id },
        expires_in: 1.hour
      )

      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id, token: token), as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/phone_calls/:id/emotion_analysis' do
    it 'runs server-side transcription and returns the persisted emotion result' do
      result = {
        'emotion' => 'khó chịu',
        'semantic_emotion' => {
          'label' => 'khó chịu',
          'reason' => 'Khách phàn nàn vì phải chờ lâu.',
          'model' => 'openai/gpt-4.1'
        },
        'transcript' => 'Tôi phải chờ quá lâu.',
        'asr_model' => 'trung381/zip-30m',
        'asr_runtime' => 'sherpa-onnx-offline',
        'llm_model' => 'openai/gpt-4.1'
      }
      service = instance_double(Phone::CallEmotionAnalysisService, perform: result)
      allow(Phone::CallEmotionAnalysisService).to receive(:new).with(phone_call).and_return(service)

      post emotion_analysis_api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id),
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('emotion' => 'khó chịu', 'transcript' => 'Tôi phải chờ quá lâu.')
      expect(phone_call.reload.metadata['emotion_analysis']).to include('emotion' => 'khó chịu')
    end

    it 'does not expose the endpoint without dashboard authentication' do
      post emotion_analysis_api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id), as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'phone call emotion reports' do
    let!(:emotion_report) do
      PhoneCallEmotionReport.create!(
        phone_call: phone_call,
        account: account,
        conversation: conversation,
        inbox: inbox,
        status: 'completed',
        emotion: 'khó',
        purpose: 'monitoring',
        action_status: 'none'
      )
    end

    let!(:unanalysed_call) do
      PhoneCall.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        conversation: conversation,
        pbx_id: 'callytics:1',
        linked_id: 'call-2',
        direction: 'inbound',
        status: 'rejected',
        customer_number: '+84963100026',
        metadata: {}
      )
    end

    it 'returns all calls and canonical emotion tags' do
      get "/api/v1/accounts/#{account.id}/phone_calls/emotion_reports",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('phone_call_id')).to contain_exactly(phone_call.id, unanalysed_call.id)
      analysed = response.parsed_body['data'].find { |item| item['phone_call_id'] == phone_call.id }
      expect(analysed).to include(
        'call_status' => 'completed',
        'emotion' => 'khó chịu',
        'emotion_tag' => { 'label' => 'khó chịu', 'color' => 'orange' }
      )
    end

    it 'filters by call status and calls without an analysis report' do
      get "/api/v1/accounts/#{account.id}/phone_calls/emotion_reports",
          params: { call_status: 'rejected', status: 'not_analyzed' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].sole).to include(
        'phone_call_id' => unanalysed_call.id,
        'call_status' => 'rejected',
        'status' => 'not_analyzed'
      )
    end

    it 'finds a historical report that stored a split emotion label' do
      emotion_report.update_columns(emotion: 'khó', emotion_color: 'green')

      get "/api/v1/accounts/#{account.id}/phone_calls/emotion_reports",
          params: { emotion: 'khó chịu' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].sole).to include(
        'phone_call_id' => phone_call.id,
        'emotion' => 'khó chịu',
        'emotion_tag' => { 'label' => 'khó chịu', 'color' => 'orange' }
      )
    end

    it 'updates the follow-up status' do
      patch "/api/v1/accounts/#{account.id}/phone_calls/#{phone_call.id}/emotion_report",
            params: { emotion_report: { action_status: 'needs_follow_up' } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['action_status']).to eq('needs_follow_up')
      expect(emotion_report.reload.action_status).to eq('needs_follow_up')
    end
  end
end
