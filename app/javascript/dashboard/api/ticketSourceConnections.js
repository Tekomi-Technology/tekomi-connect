/* global axios */
import ApiClient from './ApiClient';

class TicketSourceConnectionsAPI extends ApiClient {
  constructor() {
    super('ticket_source_connections', { accountScoped: true });
  }

  providers() {
    return axios.get(`${this.url}/providers`);
  }

  action(id, name) {
    return axios.post(`${this.url}/${id}/${name}`);
  }
}

export default new TicketSourceConnectionsAPI();
