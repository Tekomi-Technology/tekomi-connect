require 'json'

class Phone::CallEmotionAnalysisService
  LABELS = Tekomi::Llm::CallEmotionAnalysisSchema::LABELS

  def initialize(phone_call)
    @phone_call = phone_call
    @account = phone_call.account
  end

  def perform
    recording = Phone::PbxRecordingFetcher.new(@phone_call).download
    transcription = Phone::ZipformerTranscriptionService.new(recording).perform
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
      'asr_runtime' => transcription['asr_runtime'],
      'llm_model' => analysis['model'],
      'processed_at' => Time.current.iso8601
    }
  ensure
    recording&.close!
  end

  private

  def analyze_transcript(transcript)
    route = Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis')
    chat = RubyLLM.chat(model: route[:model], provider: route[:provider], assume_model_exists: true)
                     .with_params(**route[:params])
                     .with_schema(Tekomi::Llm::CallEmotionAnalysisSchema)
    response = chat.ask(
      "Transcript cuộc gọi:\n#{transcript.presence || '(trống)'}"
    )
    parsed = JSON.parse(response.content.to_s)
    label = parsed['label'].to_s
    label = 'trung tính' unless LABELS.include?(label)

    {
      'label' => label,
      'reason' => parsed['reason'].to_s.strip.presence || 'Không có bằng chứng cảm xúc rõ ràng trong transcript.',
      'model' => route[:model]
    }
  rescue JSON::ParserError => e
    raise StandardError, "LLM returned invalid emotion JSON: #{e.message}"
  end
end
