class Phone::CallEmotionAnalysisService
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
      'confidence' => analysis.fetch('confidence'),
      'probabilities' => analysis.fetch('probabilities'),
      'semantic_emotion' => {
        'label' => analysis.fetch('label'),
        'reason' => analysis.fetch('reason'),
        'model' => analysis.fetch('model'),
        'confidence' => analysis.fetch('confidence'),
        'probabilities' => analysis.fetch('probabilities')
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
    Phone::JevEmotionAnalysisService.new(transcript: transcript, account: @account).perform
  end
end
