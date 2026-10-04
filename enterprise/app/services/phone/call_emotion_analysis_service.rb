require 'json'

class Phone::CallEmotionAnalysisService
  LABELS = Tekomi::Llm::CallEmotionAnalysisSchema::LABELS

  def initialize(phone_call)
    @phone_call = phone_call
    @account = phone_call.account
  end

  def perform
    recording = Phone::PbxRecordingFetcher.new(@phone_call).download
    transcription = Phone::OpenrouterTranscriptionService.new(recording, account: @account).perform
    transcript = transcription.fetch('transcript').to_s.strip
    analysis = analyze_transcript(transcript)

    {
      'emotion' => analysis.fetch('label'),
      'confidence' => nil,
      'semantic_emotion' => {
        'label' => analysis.fetch('label'),
        'reason' => analysis.fetch('reason'),
        'model' => analysis.fetch('model')
      },
      'transcript' => transcript,
      'asr_model' => transcription['asr_model'],
      'asr_provider' => transcription['asr_provider'],
      'asr_runtime' => transcription['asr_runtime'],
      'language' => transcription['language'],
      'segments' => transcription['segments'],
      'words' => transcription['words'],
      'llm_model' => analysis['model'],
      'llm_provider' => analysis['provider'],
      'processed_at' => Time.current.iso8601
    }
  ensure
    recording&.close!
  end

  private

  def analyze_transcript(transcript)
    route = Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis', account: @account)
    chat = route[:context].chat(model: route[:model], provider: route[:provider], assume_model_exists: true)
                     .with_params(**route[:params])
                     .with_schema(Tekomi::Llm::CallEmotionAnalysisSchema)
    response = chat.ask(
      "Transcript cuộc gọi:\n#{transcript.presence || '(trống)'}"
    )
    parsed = parse_response(response.content)
    label = normalize_label(parsed['label'])

    {
      'label' => label,
      'reason' => parsed['reason'].to_s.strip.presence || 'Không có bằng chứng cảm xúc rõ ràng trong transcript.',
      'model' => route[:model],
      'provider' => route[:provider].to_s
    }
  rescue JSON::ParserError, TypeError => e
    raise StandardError, "LLM returned invalid emotion JSON: #{e.message}"
  end

  def parse_response(content)
    return content.stringify_keys if content.is_a?(Hash)

    JSON.parse(content.to_s)
  end

  def normalize_label(value)
    normalized = PhoneCallEmotionReport.normalize_emotion_label(value)
    LABELS.include?(normalized) ? normalized : 'trung tính'
  end
end
