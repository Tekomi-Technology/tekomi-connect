/* global axios */
import ApiClient from './ApiClient';

class DealAssistantAPI extends ApiClient {
  constructor() {
    super('tekomi/deal_assistant_messages', { accountScoped: true });
  }

  ask({ message, dealId, pipelineId, previousHistory }) {
    return axios.post(this.url, {
      message,
      deal_id: dealId,
      pipeline_id: pipelineId,
      previous_history: previousHistory,
    });
  }
}

export default new DealAssistantAPI();
