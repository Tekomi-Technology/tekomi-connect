/* global axios */
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

class TeamMonitoringAPI extends ApiClient {
  constructor() {
    super('team_monitoring', { accountScoped: true, apiVersion: 'v2' });
  }

  get({ since, until }) {
    return axios.get(this.url, {
      params: { since, until, timezone_offset: getTimeOffset() },
    });
  }

  getAgentConversations(userId) {
    return axios.get(`${this.url}/agent_conversations`, {
      params: { user_id: userId },
    });
  }
}

export default new TeamMonitoringAPI();
