/* global axios */
import ApiClient from './ApiClient';

class AiAlertsAPI extends ApiClient {
  constructor() {
    super('ai_alerts', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  markRead(id, read = true) {
    return axios.patch(`${this.url}/${id}`, { read });
  }

  markAllRead() {
    return axios.post(`${this.url}/mark_all_read`);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new AiAlertsAPI();
