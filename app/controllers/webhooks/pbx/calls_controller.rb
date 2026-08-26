class Webhooks::Pbx::CallsController < ActionController::API
  MAX_TIMESTAMP_DRIFT = 5.minutes

  def process_payload
    return head :service_unavailable if webhook_secret.blank?
    return head :unauthorized unless valid_signature?

    payload = JSON.parse(request.raw_post)
    Rails.logger.info({ event: 'pbx_call_webhook.received', payload: payload }.to_json)
    Phone::PbxCallEventProcessor.new(payload: payload).perform
    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue Phone::PbxCallEventProcessor::InvalidPayload => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def valid_signature?
    return false unless timestamp_fresh?

    received = request.headers['X-PBX-Signature'].to_s
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, signed_payload)}"
    received.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(received, expected)
  end

  def timestamp_fresh?
    timestamp = Integer(request.headers['X-PBX-Timestamp'], exception: false)
    timestamp.present? && (Time.current.to_i - timestamp).abs <= MAX_TIMESTAMP_DRIFT
  end

  def signed_payload
    "#{request.headers['X-PBX-Timestamp']}.#{request.raw_post}"
  end

  def webhook_secret
    ENV.fetch('PBX_CALL_WEBHOOK_SECRET', nil)
  end
end
