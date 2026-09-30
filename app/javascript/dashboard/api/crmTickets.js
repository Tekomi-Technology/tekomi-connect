/* global axios */
import ApiClient from './ApiClient';

class CrmTicketsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getByConversation(conversationId) {
    return axios.get(`${this.url}/${conversationId}/crm_tickets`);
  }
}

export default new CrmTicketsAPI();
