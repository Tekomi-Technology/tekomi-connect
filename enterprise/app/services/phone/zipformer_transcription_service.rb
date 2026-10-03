require 'json'
require 'faraday/multipart'

class Phone::ZipformerTranscriptionService
  class TranscriptionFailed < StandardError; end

  def initialize(recording)
    @recording = recording
  end

  def perform
    response = connection.post('/transcribe') do |request|
      request.body = {
        file: Faraday::Multipart::FilePart.new(@recording, 'audio/wav', 'phone-call.wav')
      }
    end

    raise TranscriptionFailed, "Zipformer returned HTTP #{response.status}" unless response.success?

    result = JSON.parse(response.body)
    transcript = result['transcript'].to_s.strip
    raise TranscriptionFailed, 'Zipformer returned an empty transcript' if transcript.blank?

    result
  rescue Faraday::Error, JSON::ParserError => e
    raise TranscriptionFailed, "Zipformer transcription failed: #{e.message}"
  end

  private

  def connection
    @connection ||= Faraday.new(url: service_url) do |faraday|
      faraday.request :multipart
      faraday.options.timeout = 180
      faraday.options.open_timeout = 10
    end
  end

  def service_url
    ENV.fetch('CALL_EMOTION_SERVICE_URL', 'http://call-emotion:8080')
  end
end
