class Webhooks::ZaloPersonalController < ActionController::API
  before_action :authenticate_worker

  # Conversation events are queued so they are serialized per thread and retried on failure.
  # The rest are configuration writes: fast, order-independent, and handled inline.
  QUEUED_EVENTS = %w[message reaction undo].freeze

  def process_payload
    event = params[:event].to_s

    if QUEUED_EVENTS.include?(event)
      ::Webhooks::ZaloPersonalEventsJob.perform_later(params.to_unsafe_hash.except('controller', 'action'))
    else
      handle_inline(event)
    end

    head :ok
  end

  private

  def handle_inline(event)
    case event
    when 'status' then channel.update_status!(params[:status])
    when 'credentials_refreshed' then channel.update!(credentials: params[:credentials].to_json)
    when 'qr_completed' then ::Zalo::QrCompletionService.new(params: params).perform
    when 'qr_failed' then ::Zalo::QrCompletionService.new(params: params).fail!
    end
  end

  def channel
    @channel ||= ::Channel::ZaloPersonal.find(params[:channel_id])
  end

  def authenticate_worker
    expected = ENV.fetch('ZALO_WORKER_SECRET')
    return if ActiveSupport::SecurityUtils.secure_compare(expected, request.headers['X-Zalo-Worker-Secret'].to_s)

    head :unauthorized
  end
end
