class Phone::JevEmotionAnalysisService
  ENDPOINT = 'https://openrouter.ai/api/v1/systemone'.freeze
  MODEL = 'typesafe/jev-1.13'.freeze
  LABELS = PhoneCallEmotionReport::EMOTION_COLORS.keys.freeze

  CRITERIA = {
    'buồn' => 'Khách hàng thể hiện buồn, thất vọng, chán nản hoặc mất hy vọng.',
    'trung tính' => 'Khách hàng trao đổi thông tin bình thường hoặc không có bằng chứng cảm xúc rõ ràng.',
    'vui' => 'Khách hàng thể hiện vui vẻ, hài lòng, biết ơn hoặc phản hồi tích cực.',
    'khó chịu' => 'Khách hàng thể hiện không hài lòng, bực bội, phàn nàn hoặc thiếu kiên nhẫn.',
    'gay gắt' => 'Khách hàng tức giận mạnh, công kích, đe dọa hoặc yêu cầu xử lý với thái độ gay gắt.'
  }.freeze

  class DecisionFailed < StandardError; end

  def initialize(transcript:, account:)
    @transcript = transcript
    @account = account
  end

  def perform
    route = Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis', account: @account)
    raise DecisionFailed, 'Jev emotion analysis requires the OpenRouter provider' unless route[:provider] == :openrouter

    response = connection(account_provider(route[:provider])).post(ENDPOINT, request_body)
    raise DecisionFailed, "OpenRouter Jev request failed with status #{response.status}" unless response.success?

    parse_response(response.body)
  rescue DecisionFailed => e
    Llm::AlertRecorder.record(
      account: @account,
      error: e,
      feature: 'call_emotion_analysis',
      provider: :openrouter,
      metadata: { model: MODEL, operation: 'emotion_analysis' }
    )
    raise
  rescue Faraday::Error, JSON::ParserError => e
    Llm::AlertRecorder.record(
      account: @account,
      error: e,
      feature: 'call_emotion_analysis',
      provider: :openrouter,
      metadata: { model: MODEL, operation: 'emotion_analysis' }
    )
    raise DecisionFailed, "OpenRouter Jev emotion analysis failed: #{e.message}"
  end

  private

  def account_provider(provider)
    @account.account_llm_providers.find_by!(provider_type: provider.to_s)
  end

  def connection(provider)
    Faraday.new do |client|
      client.options.open_timeout = 3
      client.options.timeout = 15
      client.headers['Authorization'] = "Bearer #{provider.api_key}"
      client.headers['Content-Type'] = 'application/json'
    end
  end

  def request_body
    {
      model: MODEL,
      state: { transcript: @transcript },
      questions: {
        emotion: {
          type: 'choice',
          instructions: emotion_instructions,
          criteria: CRITERIA
        }
      }
    }.to_json
  end

  def parse_response(body)
    data = JSON.parse(body)
    answer = data.dig('answers', 'emotion')
    label = answer&.[]('choice')
    confidence = answer&.[]('confidence')
    probabilities = answer&.[]('probabilities')

    unless answer&.[]('type') == 'choice' && LABELS.include?(label) && valid_confidence?(confidence) && probabilities.is_a?(Hash)
      raise DecisionFailed, 'OpenRouter Jev returned an invalid emotion decision'
    end

    {
      'label' => label,
      'confidence' => confidence,
      'probabilities' => probabilities.slice(*LABELS),
      'reason' => "Jev phân loại cảm xúc nổi bật của khách hàng là #{label} với độ tin cậy #{(confidence * 100).round}%.",
      'model' => data['model'].presence || MODEL,
      'provider' => 'openrouter'
    }
  end

  def emotion_instructions
    Tekomi::PromptRenderer.render('call_emotion_analysis', {}, account: @account)
  end

  def valid_confidence?(value)
    value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
  end
end
