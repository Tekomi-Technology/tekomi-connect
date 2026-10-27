import { computed, ref } from 'vue';
import { useWindowSize } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import wootConstants from 'dashboard/constants/globals';

const isOverlayOpen = ref(false);

export function useConversationFilterPanel() {
  const { uiSettings, updateUISettings } = useUISettings();
  const currentChat = useMapGetter('getSelectedChat');
  const { width } = useWindowSize();

  const canDock = computed(() => {
    const {
      is_contact_sidebar_open: isInfoOpen,
      is_copilot_panel_open: isAiOpen,
    } = uiSettings.value;
    const hasSidePanelOpen =
      Boolean(currentChat.value?.id) && (isInfoOpen || isAiOpen);
    return (
      width.value >= wootConstants.SIDE_PANEL_DOCK_BREAKPOINT &&
      !hasSidePanelOpen
    );
  });

  const isDocked = computed(
    () =>
      canDock.value && !uiSettings.value.is_conversation_filter_panel_collapsed
  );

  const openPanel = () => {
    if (canDock.value) {
      updateUISettings({ is_conversation_filter_panel_collapsed: false });
    } else {
      isOverlayOpen.value = !isOverlayOpen.value;
    }
  };

  const closePanel = () => {
    if (isDocked.value) {
      updateUISettings({ is_conversation_filter_panel_collapsed: true });
    } else {
      isOverlayOpen.value = false;
    }
  };

  return { isDocked, isOverlayOpen, openPanel, closePanel };
}
