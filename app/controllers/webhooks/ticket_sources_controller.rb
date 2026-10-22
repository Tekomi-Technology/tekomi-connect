class Webhooks::TicketSourcesController < ActionController::API
  def process_payload
    connection = TicketSourceConnection.enabled.find_by(webhook_token: params[:token])
    return head :not_found unless connection

    connection.adapter.verify_webhook!(request.raw_post, request.headers)
    TicketSources::ProcessWebhookJob.perform_later(connection.id, JSON.parse(request.raw_post))
    head :ok
  rescue CustomExceptions::TicketSource::AuthError
    head :unauthorized
  rescue JSON::ParserError
    head :bad_request
  end
end
