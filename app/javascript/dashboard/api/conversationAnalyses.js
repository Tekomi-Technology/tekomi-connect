/* global axios */
import ApiClient from './ApiClient';

class ConversationAnalysesAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  get(conversationId) {
    return axios.get(`${this.url}/${conversationId}/analysis`);
  }

  create(conversationId) {
    return axios.post(`${this.url}/${conversationId}/analysis`);
  }

  createCareSuggestion(conversationId) {
    return axios.post(
      `${this.url}/${conversationId}/analysis/care_suggestion`
    );
  }

  getReport(params) {
    return axios.get(`${this.baseUrl()}/conversation_analyses/report`, {
      params,
    });
  }

  getOpportunities(params) {
    return axios.get(`${this.baseUrl()}/conversation_analyses/opportunities`, {
      params,
    });
  }

  getByContact(contactId) {
    return axios.get(
      `${this.baseUrl()}/contacts/${contactId}/conversation_analyses`
    );
  }
}

export default new ConversationAnalysesAPI();
