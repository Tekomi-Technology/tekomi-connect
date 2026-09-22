class Webhooks::TicketsController < ActionController::API
  def create
    return head :not_found unless webhook
    return head :forbidden unless webhook.account.feature_enabled?('crm_tickets')

    ticket = Tickets::WebhookIntakeService.new(webhook: webhook, payload: JSON.parse(request.raw_post)).perform
    render json: { id: ticket.id }, status: :created
  rescue JSON::ParserError
    head :bad_request
  rescue Tickets::WebhookIntakeService::InvalidPayload => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def webhook
    @webhook ||= TicketWebhook.enabled.find_by(token: params[:token])
  end
end
