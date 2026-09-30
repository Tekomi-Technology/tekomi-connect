require 'net/http'
require 'openssl'
require 'tempfile'

class Phone::PbxRecordingFetcher
  MAX_BYTES = 100.megabytes

  class RecordingUnavailable < StandardError; end

  def initialize(phone_call)
    @phone_call = phone_call
  end

  def download
    source_url = @phone_call.metadata['pbx_recording_url'].to_s
    return download_callytics if source_url.blank? && @phone_call.metadata['callytics_recording_resource'].present?
    raise RecordingUnavailable, 'Call recording URL is missing' if source_url.blank?

    uri = URI.parse(source_url)
    raise RecordingUnavailable, 'PBX recording URL must use HTTPS' unless uri.is_a?(URI::HTTPS)

    tempfile = Tempfile.new(["phone-call-#{@phone_call.id}", '.wav'])
    tempfile.binmode
    request = Net::HTTP::Get.new(uri)
    add_signature_headers(request, uri)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 120) do |http|
      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise RecordingUnavailable, "PBX returned HTTP #{response.code}"
        end

        size = 0
        response.read_body do |chunk|
          size += chunk.bytesize
          raise RecordingUnavailable, 'PBX recording exceeds the analysis size limit' if size > MAX_BYTES

          tempfile.write(chunk)
        end
      end
    end

    tempfile.rewind
    tempfile
  rescue URI::InvalidURIError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    tempfile&.close!
    raise RecordingUnavailable, "Unable to fetch PBX recording: #{e.message}"
  rescue StandardError
    tempfile&.close!
    raise
  end

  def download_callytics
    resource = @phone_call.metadata['callytics_recording_resource'].to_s
    unless resource.match?(%r{\A/api/v1/vendor/call-reports/[^/]+/recording\z})
      raise RecordingUnavailable, 'Callytics recording resource is invalid'
    end

    api_key = ENV['CALLYTICS_API_KEY'].to_s
    raise RecordingUnavailable, 'Callytics API key is not configured' if api_key.blank?

    uri = URI.join(ENV.fetch('CALLYTICS_API_BASE_URL', 'https://api.app.voxa.vn'), resource)
    tempfile = Tempfile.new(["phone-call-#{@phone_call.id}", '.ogg'])
    tempfile.binmode
    request = Net::HTTP::Get.new(uri)
    request['X-Callytics-API-Key'] = api_key

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 120) do |http|
      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise RecordingUnavailable, "Callytics returned HTTP #{response.code}"
        end

        size = 0
        response.read_body do |chunk|
          size += chunk.bytesize
          raise RecordingUnavailable, 'Call recording exceeds the analysis size limit' if size > MAX_BYTES

          tempfile.write(chunk)
        end
      end
    end

    tempfile.rewind
    tempfile
  rescue URI::InvalidURIError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    tempfile&.close!
    raise RecordingUnavailable, "Unable to fetch Callytics recording: #{e.message}"
  rescue StandardError
    tempfile&.close!
    raise
  end

  private

  def add_signature_headers(request, uri)
    secret = ENV['PBX_RECORDING_FETCH_SECRET'].to_s
    raise RecordingUnavailable, 'PBX recording secret is not configured' if secret.blank?

    timestamp = Time.current.utc.iso8601
    nonce = SecureRandom.hex(16)
    payload = [timestamp, nonce, request.method, uri.request_uri].join('.')

    request['X-Chatwoot-Timestamp'] = timestamp
    request['X-Chatwoot-Nonce'] = nonce
    request['X-Chatwoot-Signature'] = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, payload)}"
  end
end
