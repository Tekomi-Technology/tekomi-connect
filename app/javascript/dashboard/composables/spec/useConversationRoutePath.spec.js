import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';

const mockRoute = { name: '', params: {}, query: {} };

vi.mock('vue-router', () => ({
  useRoute: () => mockRoute,
}));

describe('useConversationRoutePath', () => {
  beforeEach(() => {
    mockRoute.name = 'inbox_conversation';
    mockRoute.params = { accountId: '1' };
    mockRoute.query = {};
  });

  describe('buildConversationPath', () => {
    it('builds the plain conversation path', () => {
      const { buildConversationPath } = useConversationRoutePath();
      expect(buildConversationPath(5)).toBe('/app/accounts/1/conversations/5');
    });

    it('keeps the list scope from the query', () => {
      mockRoute.query = {
        inbox_id: '3',
        label: 'bug',
        team_id: '2',
        scope: 'mine',
        filter: 'unread',
      };
      const { buildConversationPath } = useConversationRoutePath();
      expect(buildConversationPath(5)).toBe(
        '/app/accounts/1/conversations/5?inbox_id=3&label=bug&team_id=2&scope=mine&filter=unread'
      );
    });

    it('ignores query keys that are not part of the list scope', () => {
      mockRoute.query = { filter: 'mention', messageId: '9' };
      const { buildConversationPath } = useConversationRoutePath();
      expect(buildConversationPath(5)).toBe(
        '/app/accounts/1/conversations/5?filter=mention'
      );
    });

    it('keeps the custom view context on folder routes', () => {
      mockRoute.name = 'folder_conversations';
      mockRoute.params = { accountId: '1', id: '7' };
      const { buildConversationPath } = useConversationRoutePath();
      expect(buildConversationPath(5)).toBe(
        '/app/accounts/1/custom_view/7/conversations/5'
      );
    });

    it('drops the custom view context when the folder scope is not kept', () => {
      mockRoute.name = 'folder_conversations';
      mockRoute.params = { accountId: '1', id: '7' };
      const { buildConversationPath } = useConversationRoutePath();
      expect(buildConversationPath(5, { keepFolderScope: false })).toBe(
        '/app/accounts/1/conversations/5'
      );
    });
  });

  describe('buildConversationListPath', () => {
    it('builds the plain list path', () => {
      const { buildConversationListPath } = useConversationRoutePath();
      expect(buildConversationListPath()).toBe('/app/accounts/1/dashboard');
    });

    it('keeps the list scope from the query', () => {
      mockRoute.query = { inbox_id: '3', scope: 'mine', filter: 'pinned' };
      const { buildConversationListPath } = useConversationRoutePath();
      expect(buildConversationListPath()).toBe(
        '/app/accounts/1/dashboard?inbox_id=3&scope=mine&filter=pinned'
      );
    });

    it('keeps the custom view context on folder routes', () => {
      mockRoute.name = 'conversations_through_folders';
      mockRoute.params = { accountId: '1', id: '7' };
      const { buildConversationListPath } = useConversationRoutePath();
      expect(buildConversationListPath()).toBe('/app/accounts/1/custom_view/7');
    });
  });
});
