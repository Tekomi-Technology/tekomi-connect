class Api::V1::Accounts::AiAlertsController < Api::V1::Accounts::BaseController
  before_action :authorize_account_admin
  before_action :fetch_alert, only: [:update, :destroy]

  def index
    alerts = Current.account.ai_alerts.recent_first
    alerts = alerts.where(category: params[:category]) if params[:category].present?
    alerts = alerts.where(read_at: nil) if ActiveModel::Type::Boolean.new.cast(params[:unread])

    page = [params.fetch(:page, 1).to_i, 1].max
    limit = params.fetch(:limit, 50).to_i.clamp(1, 100)
    total = alerts.count
    alerts = alerts.offset((page - 1) * limit).limit(limit)

    render json: {
      data: alerts.map(&:push_event_data),
      meta: {
        current_page: page,
        per_page: limit,
        total_entries: total,
        total_pages: (total.to_f / limit).ceil,
        unread_count: Current.account.ai_alerts.unread.count
      }
    }
  end

  def update
    @alert.update!(read_at: read_alert? ? Time.current : nil)
    Llm::AlertRecorder.broadcast(@alert)
    render json: @alert.push_event_data
  end

  def destroy
    account = @alert.account
    @alert.destroy!
    Llm::AlertRecorder.broadcast_account(
      account,
      'ai_alert.deleted',
      ai_alert: { id: @alert.id },
      unread_count: account.ai_alerts.unread.count,
      count: account.ai_alerts.count
    )
    head :no_content
  end

  def mark_all_read
    Current.account.ai_alerts.unread.update_all(read_at: Time.current)
    Llm::AlertRecorder.broadcast_account(
      Current.account,
      'ai_alerts.marked_read',
      unread_count: 0,
      count: Current.account.ai_alerts.count
    )
    head :no_content
  end

  private

  def authorize_account_admin
    authorize Current.account, :update?
  end

  def fetch_alert
    @alert = Current.account.ai_alerts.find(params[:id])
  end

  def read_alert?
    return true unless params.key?(:read)

    ActiveModel::Type::Boolean.new.cast(params[:read])
  end
end
