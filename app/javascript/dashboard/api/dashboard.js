/* global axios */
import ApiClient from './ApiClient';

class DashboardAPI extends ApiClient {
  constructor() {
    super('dashboard', { accountScoped: true, apiVersion: 'v2' });
  }

  get(params) {
    return axios.get(this.url, { params });
  }
}

export default new DashboardAPI();
