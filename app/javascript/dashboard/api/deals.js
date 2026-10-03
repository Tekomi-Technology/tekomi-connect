/* global axios */
import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  filter(params) {
    return axios.post(`${this.url}/filter`, params);
  }

  move(id, { stageId, afterId }) {
    return axios.patch(`${this.url}/${id}/move`, {
      stage_id: stageId,
      after_id: afterId,
    });
  }

  getConversations(id) {
    return axios.get(`${this.url}/${id}/conversations`);
  }

  linkConversation(id, conversationId) {
    return axios.post(`${this.url}/${id}/conversations`, {
      conversation_id: conversationId,
    });
  }

  unlinkConversation(id, conversationId) {
    return axios.delete(`${this.url}/${id}/conversations/${conversationId}`);
  }

  getActivities(id) {
    return axios.get(`${this.url}/${id}/activities`);
  }

  getByContact(contactId) {
    return axios.get(`${this.baseUrl()}/contacts/${contactId}/deals`);
  }

  getByConversation(conversationId) {
    return axios.get(`${this.baseUrl()}/conversations/${conversationId}/deals`);
  }
}

export default new DealsAPI();
