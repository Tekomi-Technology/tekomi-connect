/* global axios */
import ApiClient from './ApiClient';

class DealNextStepsAPI extends ApiClient {
  constructor() {
    super('tekomi/deal_next_steps', { accountScoped: true });
  }

  generate(dealId) {
    return axios.post(this.url, { deal_id: dealId });
  }
}

export default new DealNextStepsAPI();
