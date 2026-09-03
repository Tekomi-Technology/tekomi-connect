import { frontendURL } from '../../../helper/URLHelper';
import HomeIndex from './Index.vue';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/home'),
    name: 'account_home',
    component: HomeIndex,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
];
