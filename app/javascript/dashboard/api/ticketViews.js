/* global axios */
import ApiClient from './ApiClient';

// Saved views are shared with deals on the server, so reads and writes here
// always carry the ticket object type.
class TicketViewsAPI extends ApiClient {
  constructor() {
    super('saved_views', { accountScoped: true });
  }

  get(pipelineId) {
    return axios.get(this.url, {
      params: { object_type: 'ticket', pipeline_id: pipelineId },
    });
  }

  create(payload) {
    return axios.post(this.url, {
      saved_view: { ...payload.saved_view, object_type: 'ticket' },
    });
  }
}

export default new TicketViewsAPI();
