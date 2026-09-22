json.payload do
  json.array! @ticket_webhooks do |ticket_webhook|
    json.partial! 'api/v1/accounts/ticket_webhooks/ticket_webhook', formats: [:json], resource: ticket_webhook
  end
end
