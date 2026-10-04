require 'rails_helper'

RSpec.describe Phone::JevEmotionAnalysisService do
  subject(:service) { described_class.new(transcript: transcript, account: account) }

  let(:transcript) { 'Tôi đã phải gọi ba lần rồi, rất mất thời gian.' }
  let(:provider) { instance_double(AccountLlmProvider, api_key: 'tenant-openrouter-key') }
  let(:providers) { instance_double(ActiveRecord::Associations::CollectionProxy) }
  let(:account) { instance_double(Account, account_llm_providers: providers) }

  before do
    allow(Llm::FeatureRouter).to receive(:resolve)
      .with(feature: 'call_emotion_analysis', account: account)
      .and_return(provider: :openrouter)
    allow(providers).to receive(:find_by!).with(provider_type: 'openrouter').and_return(provider)
  end

  it 'returns the typed Jev emotion decision with calibrated probabilities' do
    stub_request(:post, described_class::ENDPOINT)
      .with(headers: { 'Authorization' => 'Bearer tenant-openrouter-key' })
      .to_return(
        status: 200,
        body: {
          model: 'typesafe/jev-1.13-20260917',
          answers: {
            emotion: {
              type: 'choice',
              choice: 'khó chịu',
              confidence: 0.91,
              probabilities: {
                'buồn' => 0.02,
                'trung tính' => 0.04,
                'vui' => 0.01,
                'khó chịu' => 0.91,
                'gay gắt' => 0.02
              }
            }
          }
        }.to_json
      )

    result = service.perform

    expect(result).to include(
      'label' => 'khó chịu',
      'confidence' => 0.91,
      'model' => 'typesafe/jev-1.13-20260917',
      'provider' => 'openrouter'
    )
    expect(result['probabilities']).to include('khó chịu' => 0.91)
    expect(result['reason']).to include('91%')
    expect(WebMock).to have_requested(:post, described_class::ENDPOINT).with do |request|
      payload = JSON.parse(request.body)
      payload['model'] == 'typesafe/jev-1.13' &&
        payload.dig('state', 'transcript') == transcript &&
        payload.dig('questions', 'emotion', 'type') == 'choice'
    end
  end

  it 'rejects an invalid decision response' do
    stub_request(:post, described_class::ENDPOINT)
      .to_return(status: 200, body: { answers: { emotion: { type: 'choice', choice: 'bực' } } }.to_json)

    expect { service.perform }
      .to raise_error(described_class::DecisionFailed, 'OpenRouter Jev returned an invalid emotion decision')
  end

  it 'rejects a non-OpenRouter feature provider before sending a request' do
    allow(Llm::FeatureRouter).to receive(:resolve)
      .with(feature: 'call_emotion_analysis', account: account)
      .and_return(provider: :openai)

    expect { service.perform }
      .to raise_error(described_class::DecisionFailed, 'Jev emotion analysis requires the OpenRouter provider')
  end
end
