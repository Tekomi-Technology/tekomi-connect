/* eslint arrow-body-style: 0 */
import { frontendURL } from '../../../helper/URLHelper';
import store from '../../../store';
import ConversationView from './ConversationView.vue';
import { conversationListQuery } from '../../../helper/URLHelper';

const CONVERSATION_PERMISSIONS = [
  'administrator',
  'supervisor',
  'agent',
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

const isFolderAvailable = async folderId => {
  let folders = store.getters['customViews/getConversationCustomViews'];
  if (!folders.length) {
    await store.dispatch('customViews/get', 'conversation');
    folders = store.getters['customViews/getConversationCustomViews'];
  }
  return folders.some(folder => folder.id === Number(folderId));
};

const redirectFolderListIfUnavailable = async (to, _from, next) => {
  if (await isFolderAvailable(to.params.id)) {
    next();
    return;
  }
  next({ name: 'home', params: { accountId: to.params.accountId } });
};

const redirectFolderConversationIfUnavailable = async (to, _from, next) => {
  if (await isFolderAvailable(to.params.id)) {
    next();
    return;
  }
  next({
    name: 'inbox_conversation',
    params: {
      accountId: to.params.accountId,
      conversation_id: to.params.conversation_id,
    },
  });
};

const listProps = route => ({
  inboxId: route.query.inbox_id || 0,
  label: route.query.label || '',
  teamId: route.query.team_id || '',
  conversationType: route.query.scope === 'mine' ? 'mine' : '',
  quickFilter: route.query.filter || '',
  conversationId: route.params.conversation_id || 0,
});

const redirectToList = scopeFromRoute => to => ({
  name: to.params.conversation_id ? 'inbox_conversation' : 'home',
  params: {
    accountId: to.params.accountId,
    ...(to.params.conversation_id && {
      conversation_id: to.params.conversation_id,
    }),
  },
  query: { ...to.query, ...conversationListQuery(scopeFromRoute(to)) },
});

const legacyListRoutes = [
  [
    'inbox_dashboard',
    'inbox/:inbox_id',
    to => ({ inboxId: to.params.inbox_id }),
  ],
  ['label_conversations', 'label/:label', to => ({ label: to.params.label })],
  ['team_conversations', 'team/:teamId', to => ({ teamId: to.params.teamId })],
  [
    'conversation_mentions',
    'mentions/conversations',
    () => ({ conversationType: 'mention' }),
  ],
  [
    'conversation_unattended',
    'unattended/conversations',
    () => ({ conversationType: 'unattended' }),
  ],
  [
    'conversation_participating',
    'participating/conversations',
    () => ({ conversationType: 'participating' }),
  ],
  [
    'conversation_mine',
    'mine/conversations',
    () => ({ conversationType: 'mine' }),
  ],
];

const legacyConversationRoutes = [
  [
    'conversation_through_inbox',
    'inbox/:inbox_id/conversations/:conversation_id',
    to => ({ inboxId: to.params.inbox_id }),
  ],
  [
    'conversations_through_label',
    'label/:label/conversations/:conversation_id',
    to => ({ label: to.params.label }),
  ],
  [
    'conversations_through_team',
    'team/:teamId/conversations/:conversation_id',
    to => ({ teamId: to.params.teamId }),
  ],
  [
    'conversation_through_mentions',
    'mentions/conversations/:conversation_id',
    () => ({ conversationType: 'mention' }),
  ],
  [
    'conversation_through_unattended',
    'unattended/conversations/:conversation_id',
    () => ({ conversationType: 'unattended' }),
  ],
  [
    'conversation_through_participating',
    'participating/conversations/:conversation_id',
    () => ({ conversationType: 'participating' }),
  ],
  [
    'conversation_through_mine',
    'mine/conversations/:conversation_id',
    () => ({ conversationType: 'mine' }),
  ],
];

const legacyRedirects = [...legacyListRoutes, ...legacyConversationRoutes].map(
  ([name, path, scopeFromRoute]) => ({
    path: frontendURL(`accounts/:accountId/${path}`),
    name,
    meta: { permissions: CONVERSATION_PERMISSIONS },
    redirect: redirectToList(scopeFromRoute),
  })
);

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/dashboard'),
      name: 'home',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: listProps,
    },
    {
      path: frontendURL('accounts/:accountId/conversations/:conversation_id'),
      name: 'inbox_conversation',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: listProps,
    },
    {
      path: frontendURL('accounts/:accountId/custom_view/:id'),
      name: 'folder_conversations',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      beforeEnter: redirectFolderListIfUnavailable,
      component: ConversationView,
      props: route => ({ foldersId: route.params.id }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/custom_view/:id/conversations/:conversation_id'
      ),
      name: 'conversations_through_folders',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      beforeEnter: redirectFolderConversationIfUnavailable,
      props: route => ({
        conversationId: route.params.conversation_id,
        foldersId: route.params.id,
      }),
    },
    ...legacyRedirects,
  ],
};
