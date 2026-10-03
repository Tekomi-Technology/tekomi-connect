/* global axios */
import ApiClient from './ApiClient';

class DealSummariesAPI extends ApiClient {
  constructor() {
    super('tekomi/deal_summaries', { accountScoped: true });
  }

  generate(dealId) {
    return axios.post(this.url, { deal_id: dealId });
  }
}

export default new DealSummariesAPI();
