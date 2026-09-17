/* global axios */
import ApiClient from './ApiClient';

class SavedViewsAPI extends ApiClient {
  constructor() {
    super('saved_views', { accountScoped: true });
  }

  get(pipelineId) {
    return axios.get(this.url, {
      params: { object_type: 'deal', pipeline_id: pipelineId },
    });
  }
}

export default new SavedViewsAPI();
