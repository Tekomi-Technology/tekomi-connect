/* global axios */
import ApiClient from './ApiClient';

class DealSuggestionsAPI extends ApiClient {
  constructor() {
    super('tekomi/deal_suggestions', { accountScoped: true });
  }

  scan({ days } = {}) {
    return axios.post(this.url, { days });
  }
}

export default new DealSuggestionsAPI();
