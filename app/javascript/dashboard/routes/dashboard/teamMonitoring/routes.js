import { frontendURL } from '../../../helper/URLHelper';
import TeamMonitoringIndex from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/team-monitoring'),
    name: 'team_monitoring_index',
    component: TeamMonitoringIndex,
    meta: {
      permissions: ['administrator', 'supervisor'],
    },
  },
];
