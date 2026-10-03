require 'rails_helper'

RSpec.describe 'Webhooks::Pbx::CallsController', type: :request do
  let(:secret) { 'test-pbx-webhook-secret' }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:payload) do
    {
      event_id: 'call.completed:leg-1',
      event: 'call.completed',
      pbx_call_id: 'call-1',
      leg_uuid: 'leg-1',
      from_number: '84901234567',
      to_number: '1001'
    }
  end
  let(:body) { payload.to_json }
  let(:signature) { "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}" }
  let(:headers) do
    {
      'CONTENT_TYPE' => 'application/json',
      'X-PBX-Timestamp' => timestamp,
      'X-PBX-Signature' => signature
    }
  end
  let(:processor) { instance_double(Phone::PbxCallEventProcessor, perform: nil) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PBX_CALL_WEBHOOK_SECRET', nil).and_return(secret)
    allow(Phone::PbxCallEventProcessor).to receive(:new).and_return(processor)
  end

  it 'writes the verified event to the structured Rails log' do
    allow(Rails.logger).to receive(:info)

    post '/webhooks/pbx/calls', params: body, headers: headers

    expect(response).to have_http_status(:ok)
    expect(Rails.logger).to have_received(:info).with(include('pbx_call_webhook.received', 'call.completed', 'call-1'))
    expect(processor).to have_received(:perform)
  end

  it 'rejects an invalid signature' do
    headers['X-PBX-Signature'] = 'sha256=invalid'

    post '/webhooks/pbx/calls', params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a stale timestamp' do
    stale_timestamp = 10.minutes.ago.to_i.to_s
    stale_signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{stale_timestamp}.#{body}")}"
    headers['X-PBX-Timestamp'] = stale_timestamp
    headers['X-PBX-Signature'] = stale_signature

    post '/webhooks/pbx/calls', params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns service unavailable when the secret is not configured' do
    allow(ENV).to receive(:fetch).with('PBX_CALL_WEBHOOK_SECRET', nil).and_return(nil)

    post '/webhooks/pbx/calls', params: body, headers: headers

    expect(response).to have_http_status(:service_unavailable)
  end
end
