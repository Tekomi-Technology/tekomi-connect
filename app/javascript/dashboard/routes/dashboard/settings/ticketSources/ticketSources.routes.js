import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import { TICKET_SOURCE_PERMISSIONS } from 'dashboard/constants/permissions';
import SettingsWrapper from '../SettingsWrapper.vue';
import TicketSourcesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ticket-sources'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_ticket_sources_index',
          component: TicketSourcesIndex,
          meta: {
            featureFlag: FEATURE_FLAGS.CRM_TICKETS,
            permissions: ['administrator', TICKET_SOURCE_PERMISSIONS],
          },
        },
      ],
    },
  ],
};
