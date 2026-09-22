import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.CRM_TICKETS,
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/webhook'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'webhook_index',
          meta,
          component: Index,
        },
      ],
    },
  ],
};
