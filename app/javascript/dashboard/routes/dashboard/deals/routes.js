import { frontendURL } from '../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../featureFlags';
import DealsIndex from './pages/DealsIndex.vue';
import DealShow from './pages/DealShow.vue';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM_DEALS,
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/deals'),
    name: 'deals_dashboard_index',
    component: DealsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/deals/pipelines/:pipelineId'),
    name: 'deals_pipeline_index',
    component: DealsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/deals/:dealId'),
    name: 'deals_show',
    component: DealShow,
    meta: commonMeta,
  },
];
