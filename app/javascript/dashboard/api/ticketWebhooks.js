import ApiClient from './ApiClient';

class TicketWebhooksAPI extends ApiClient {
  constructor() {
    super('ticket_webhooks', { accountScoped: true });
  }
}

export default new TicketWebhooksAPI();
