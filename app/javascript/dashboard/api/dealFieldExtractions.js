/* global axios */
import ApiClient from './ApiClient';

class DealFieldExtractionsAPI extends ApiClient {
  constructor() {
    super('tekomi/deal_field_extractions', { accountScoped: true });
  }

  extract(dealId) {
    return axios.post(this.url, { deal_id: dealId });
  }
}

export default new DealFieldExtractionsAPI();
