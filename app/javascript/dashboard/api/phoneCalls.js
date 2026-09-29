/* global axios */

import ApiClient from './ApiClient';

class PhoneCalls extends ApiClient {
  constructor() {
    super('phone_calls', { accountScoped: true });
  }

  emotionAnalysis(id) {
    return axios.post(`${this.url}/${id}/emotion_analysis`);
  }
}

export default new PhoneCalls();
