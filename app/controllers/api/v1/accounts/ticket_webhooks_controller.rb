class Api::V1::Accounts::TicketWebhooksController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  before_action :check_admin_authorization?

  def index
    @ticket_webhooks = Current.account.ticket_webhooks.order(:id)
  end

  def create
    @ticket_webhook = Current.account.ticket_webhooks.create!(ticket_webhook_params)
  end

  def destroy
    Current.account.ticket_webhooks.find(params[:id]).destroy!
    head :ok
  end

  private

  def ticket_webhook_params
    params.require(:ticket_webhook).permit(:name, :pipeline_id, :enabled)
  end
end
