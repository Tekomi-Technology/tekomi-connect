class Phone::OpenrouterTranscriptionService
  MODEL = 'microsoft/mai-transcribe-2'.freeze

  class TranscriptionFailed < StandardError; end

  def initialize(recording, account:)
    @recording = recording
    @account = account
  end

  def perform
    route = Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis', account: @account)
    transcription = RubyLLM.transcribe(
      @recording.path,
      model: MODEL,
      provider: route[:provider],
      context: route[:context],
      assume_model_exists: true,
      language: 'vi',
      format: 'verbose_json',
      timestamps: :word
    )

    transcript = transcription.text.to_s.strip
    raise TranscriptionFailed, 'OpenRouter returned an empty transcript' if transcript.blank?

    {
      'transcript' => transcript,
      'asr_model' => MODEL,
      'asr_provider' => route[:provider].to_s,
      'asr_runtime' => 'ruby_llm_transcription',
      'language' => transcription.language,
      'segments' => transcription.segments
    }.compact
  rescue TranscriptionFailed
    raise
  rescue StandardError => e
    Rails.logger.warn("OpenRouter call transcription failed: #{e.class}: #{e.message}")
    raise TranscriptionFailed, "OpenRouter transcription failed: #{e.message}"
  end
end
