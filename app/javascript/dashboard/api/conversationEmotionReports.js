/* global axios */

import ApiClient from './ApiClient';

class ConversationEmotionReports extends ApiClient {
  constructor() {
    super('conversation_emotion_reports', { accountScoped: true });
  }

  getReports(params = {}) {
    return axios.get(this.url, { params });
  }

  updateReport(id, data) {
    return axios.patch(`${this.url}/${id}`, {
      conversation_emotion_report: data,
    });
  }
}

export default new ConversationEmotionReports();
