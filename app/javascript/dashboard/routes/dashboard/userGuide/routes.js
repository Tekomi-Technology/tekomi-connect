import { frontendURL } from '../../../helper/URLHelper';
import UserGuideIndex from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/user-guide'),
    name: 'user_guide_index',
    component: UserGuideIndex,
    meta: {
      permissions: ['administrator', 'supervisor', 'agent', 'custom_role'],
    },
  },
];
