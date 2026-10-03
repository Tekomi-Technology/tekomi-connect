import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import SettingsWrapper from '../SettingsWrapper.vue';
import PipelinesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/pipelines'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_pipelines_index',
          component: PipelinesIndex,
          meta: {
            featureFlag: FEATURE_FLAGS.CRM_DEALS,
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
