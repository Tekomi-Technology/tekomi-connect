/* global axios */
import ApiClient from './ApiClient';

class TicketReportsAPI extends ApiClient {
  constructor() {
    super('ticket_reports', { accountScoped: true, apiVersion: 'v2' });
  }

  get({ since, until, pipelineId }) {
    return axios.get(this.url, {
      params: { since, until, pipeline_id: pipelineId },
    });
  }
}

export default new TicketReportsAPI();
