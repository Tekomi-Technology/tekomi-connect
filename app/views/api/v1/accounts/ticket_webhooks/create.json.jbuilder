json.partial! 'api/v1/accounts/ticket_webhooks/ticket_webhook', formats: [:json], resource: @ticket_webhook
json.token @ticket_webhook.token
