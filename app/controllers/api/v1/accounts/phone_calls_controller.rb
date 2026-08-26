class Api::V1::Accounts::PhoneCallsController < Api::V1::Accounts::BaseController
  include ActionController::Live

  before_action :phone_call

  # The dashboard calls Chatwoot, never the PBX. Chatwoot authorizes the agent
  # then proxies a short-lived HMAC-authenticated request to the PBX.
  def recording
    source_url = @phone_call.metadata['pbx_recording_url'].presence
    return head :not_found unless source_url && recording_secret.present?

    uri = URI.parse(source_url)
    return head :bad_gateway unless uri.is_a?(URI::HTTPS)

    request_to_pbx = Net::HTTP::Get.new(uri)
    request_to_pbx['Range'] = request.headers['Range'] if request.headers['Range'].present?
    timestamp = Time.current.utc.iso8601
    nonce = SecureRandom.hex(16)
    request_to_pbx['X-Chatwoot-Timestamp'] = timestamp
    request_to_pbx['X-Chatwoot-Nonce'] = nonce
    request_to_pbx['X-Chatwoot-Signature'] = recording_signature(timestamp, nonce, request_to_pbx.method, uri.request_uri)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 60) do |http|
      http.request(request_to_pbx) do |pbx_response|
        self.status = pbx_response.code.to_i
        response.headers['Content-Type'] = pbx_response['Content-Type'].presence || 'audio/wav'
        response.headers['Accept-Ranges'] = pbx_response['Accept-Ranges'] || 'bytes'
        response.headers['Content-Range'] = pbx_response['Content-Range'] if pbx_response['Content-Range'].present?
        response.headers['Content-Length'] = pbx_response['Content-Length'] if pbx_response['Content-Length'].present?
        response.headers['Cache-Control'] = 'private, no-store'
        pbx_response.read_body { |chunk| response.stream.write(chunk) }
      end
    end
  rescue URI::InvalidURIError, SocketError, Net::OpenTimeout, Net::ReadTimeout
    head :bad_gateway
  ensure
    response.stream.close
  end

  private

  def phone_call
    @phone_call = PhoneCall.where(account: Current.account).find(params[:id])
    authorize @phone_call.conversation, :show?
  end

  def recording_secret
    ENV.fetch('PBX_RECORDING_FETCH_SECRET', nil)
  end

  def recording_signature(timestamp, nonce, method, request_uri)
    payload = [timestamp, nonce, method, request_uri].join('.')
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', recording_secret, payload)}"
  end
end
