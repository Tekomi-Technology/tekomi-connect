import ConversationAPI from '../../api/conversations';
import types from '../mutation-types';

export const state = {
  allCount: 0,
  inboxes: {},
  labels: {},
  teams: {},
  mentionsCount: 0,
  participatingCount: 0,
  unattendedCount: 0,
  folders: {},
  quickFilters: {},
};

const QUICK_FILTER_COUNT_KEYS = [
  'unassigned_count',
  'pinned_count',
  'direct_count',
  'group_count',
  'mine_all_count',
  'mine_unattended_count',
  'mine_pinned_count',
  'mine_direct_count',
  'mine_group_count',
  'mine_mentions_count',
  'mine_participating_count',
];

const normalizeCount = count => {
  const parsedCount = Number(count);
  return Number.isFinite(parsedCount) && parsedCount > 0 ? parsedCount : 0;
};

const normalizeCounts = counts => {
  return Object.entries(counts || {}).reduce((result, [id, count]) => {
    const parsedCount = normalizeCount(count);
    if (parsedCount > 0) {
      result[String(id)] = parsedCount;
    }

    return result;
  }, {});
};

export const getters = {
  getAllUnreadCount($state) {
    return $state.allCount;
  },
  getInboxUnreadCount: $state => inboxId => {
    return $state.inboxes[String(inboxId)] || 0;
  },
  getLabelUnreadCount: $state => labelId => {
    return $state.labels[String(labelId)] || 0;
  },
  getTeamUnreadCount: $state => teamId => {
    return $state.teams[String(teamId)] || 0;
  },
  getMentionsUnreadCount($state) {
    return $state.mentionsCount;
  },
  getParticipatingUnreadCount($state) {
    return $state.participatingCount;
  },
  getUnattendedUnreadCount($state) {
    return $state.unattendedCount;
  },
  getFolderUnreadCount: $state => folderId => {
    return $state.folders[String(folderId)] || 0;
  },
  getInboxUnreadCounts($state) {
    return $state.inboxes;
  },
  getLabelUnreadCounts($state) {
    return $state.labels;
  },
  getTeamUnreadCounts($state) {
    return $state.teams;
  },
  getFolderUnreadCounts($state) {
    return $state.folders;
  },
  getQuickFilterCounts($state) {
    return $state.quickFilters;
  },
  getMineUnreadCount($state) {
    return $state.quickFilters.mine_all_count || 0;
  },
};

export const actions = {
  get: async function getUnreadCounts({ commit }) {
    try {
      const response = await ConversationAPI.getUnreadCounts();
      commit(types.SET_CONVERSATION_UNREAD_COUNTS, response.data.payload);
    } catch (error) {
      // Ignore errors so the sidebar can continue rendering without badges.
    }
  },
  clear({ commit }) {
    commit(types.SET_CONVERSATION_UNREAD_COUNTS, {});
  },
};

export const mutations = {
  [types.SET_CONVERSATION_UNREAD_COUNTS]($state, payload = {}) {
    $state.allCount = normalizeCount(payload.all_count);
    $state.inboxes = normalizeCounts(payload.inboxes);
    $state.labels = normalizeCounts(payload.labels);
    $state.teams = normalizeCounts(payload.teams);
    $state.mentionsCount = normalizeCount(payload.mentions_count);
    $state.participatingCount = normalizeCount(payload.participating_count);
    $state.unattendedCount = normalizeCount(payload.unattended_count);
    $state.folders = normalizeCounts(payload.folders);
    $state.quickFilters = Object.fromEntries(
      QUICK_FILTER_COUNT_KEYS.map(key => [key, normalizeCount(payload[key])])
    );
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
