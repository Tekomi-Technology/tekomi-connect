/* global axios */
import ApiClient from './ApiClient';

class TicketsAPI extends ApiClient {
  constructor() {
    super('tickets', { accountScoped: true });
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

  getActivities(id) {
    return axios.get(`${this.url}/${id}/activities`);
  }

  addNote(id, content) {
    return axios.post(`${this.url}/${id}/activities`, { content });
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

  getByContact(contactId) {
    return axios.get(`${this.baseUrl()}/contacts/${contactId}/tickets`);
  }

  getByConversation(conversationId) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/tickets`
    );
  }
}

export default new TicketsAPI();
