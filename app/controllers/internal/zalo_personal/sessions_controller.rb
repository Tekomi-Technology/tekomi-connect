# The worker holds its sessions in memory, so after a restart it asks Rails which channels to
# reconnect. Credentials travel over loopback to a process that already needs them to log in.
class Internal::ZaloPersonal::SessionsController < ActionController::API
  before_action :authenticate_worker

  def index
    sessions = ::Channel::ZaloPersonal.find_each.map do |channel|
      { channel_id: channel.id, credentials: channel.parsed_credentials }
    end

    render json: { sessions: sessions }
  end

  private

  def authenticate_worker
    expected = ENV.fetch('ZALO_WORKER_SECRET')
    return if ActiveSupport::SecurityUtils.secure_compare(expected, request.headers['X-Zalo-Worker-Secret'].to_s)

    head :unauthorized
  end
end
