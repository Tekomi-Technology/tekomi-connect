import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';
import TicketsIndex from './pages/TicketsIndex.vue';
import TicketShow from './pages/TicketShow.vue';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM_TICKETS,
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tickets'),
    name: 'tickets_dashboard_index',
    component: TicketsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/tickets/pipelines/:pipelineId'),
    name: 'tickets_pipeline_index',
    component: TicketsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/tickets/:ticketId'),
    name: 'tickets_show',
    component: TicketShow,
    meta: commonMeta,
  },
];
