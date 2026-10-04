import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';

/**
 * Composable to determine if the current user is an administrator.
 * @returns {Boolean} - True if the current user is an administrator, false otherwise.
 */
export function useAdmin() {
  const getters = useStoreGetters();

  const currentUserRole = computed(() => getters.getCurrentRole.value);
  const isAdmin = computed(() => currentUserRole.value === 'administrator');
  const isSupervisor = computed(() => currentUserRole.value === 'supervisor');
  // Administrators and supervisors see every conversation in the account.
  const hasFullConversationAccess = computed(() =>
    ['administrator', 'supervisor'].includes(currentUserRole.value)
  );

  return {
    isAdmin,
    isSupervisor,
    hasFullConversationAccess,
  };
}
