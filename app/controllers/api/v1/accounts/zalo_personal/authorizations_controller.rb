class Api::V1::Accounts::ZaloPersonal::AuthorizationsController < Api::V1::Accounts::BaseController
  before_action :authorize_request

  QR_SESSION_TTL = 5.minutes

  # Polled by the dashboard while the QR code is on screen.
  def show
    raw = ::Redis::Alfred.get(cache_key(params[:qr_session_id]))
    return render json: { status: 'expired' } if raw.blank?

    session = JSON.parse(raw).with_indifferent_access
    # A QR session id is a bearer token for whatever inbox it creates; scope it to its account.
    return render json: { status: 'expired' } if session[:account_id] != Current.account.id

    render json: session.slice(:status, :inbox_id, :error)
  end

  # Starts a QR login. Pass channel_id to re-authenticate an existing inbox whose session expired.
  def create
    started = ::Zalo::WorkerClient.start_qr_login
    qr_session_id = started['qr_session_id']

    ::Redis::Alfred.setex(cache_key(qr_session_id), pending_payload.to_json, QR_SESSION_TTL)

    render json: { qr_session_id: qr_session_id, qr_image: started['qr_image'] }
  end

  private

  def authorize_request
    authorize ::Inbox, :create?
  end

  def pending_payload
    {
      account_id: Current.account.id,
      channel_id: reauth_channel&.id,
      status: 'pending'
    }
  end

  # find_by! so a channel id from another account reads as not found rather than silently
  # starting a login that can never complete.
  def reauth_channel
    return if params[:channel_id].blank?

    @reauth_channel ||= Current.account.zalo_personal_channels.find(params[:channel_id])
  end

  def cache_key(qr_session_id)
    format(::Redis::Alfred::ZALO_PERSONAL_QR_SESSION, qr_session_id: qr_session_id)
  end
end
