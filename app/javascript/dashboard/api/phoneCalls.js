/* global axios */

import ApiClient from './ApiClient';

class PhoneCalls extends ApiClient {
  constructor() {
    super('phone_calls', { accountScoped: true });
  }

  emotionAnalysis(id) {
    return axios.post(`${this.url}/${id}/emotion_analysis`);
  }

  emotionReports(params = {}) {
    return axios.get(`${this.url}/emotion_reports`, { params });
  }

  emotionReport(id) {
    return axios.get(`${this.url}/${id}/emotion_report`);
  }

  updateEmotionReport(id, data) {
    return axios.patch(`${this.url}/${id}/emotion_report`, {
      emotion_report: data,
    });
  }
}

export default new PhoneCalls();
