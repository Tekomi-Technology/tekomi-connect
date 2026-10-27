import { computed } from 'vue';
import { useRoute } from 'vue-router';
import {
  frontendURL,
  pickConversationListQuery,
} from 'dashboard/helper/URLHelper';
import { isOnFoldersView } from 'dashboard/store/modules/conversations/helpers/actionHelpers';

export function useConversationRoutePath() {
  const route = useRoute();

  const isOnFolderView = computed(() =>
    isOnFoldersView({ route: { name: route.name } })
  );

  const listQuery = () => {
    const query = pickConversationListQuery(route.query);
    return Object.keys(query).length ? query : undefined;
  };

  const buildConversationPath = (
    conversationId,
    { keepFolderScope = true } = {}
  ) => {
    const { accountId, id: folderId } = route.params;
    if (keepFolderScope && isOnFolderView.value) {
      return frontendURL(
        `accounts/${accountId}/custom_view/${folderId}/conversations/${conversationId}`
      );
    }
    return frontendURL(
      `accounts/${accountId}/conversations/${conversationId}`,
      listQuery()
    );
  };

  const buildConversationListPath = ({ keepFolderScope = true } = {}) => {
    const { accountId, id: folderId } = route.params;
    if (keepFolderScope && isOnFolderView.value) {
      return frontendURL(`accounts/${accountId}/custom_view/${folderId}`);
    }
    return frontendURL(`accounts/${accountId}/dashboard`, listQuery());
  };

  return { buildConversationPath, buildConversationListPath, isOnFolderView };
}
