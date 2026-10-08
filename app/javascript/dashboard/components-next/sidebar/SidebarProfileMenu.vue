<script setup>
import { computed } from 'vue';
import Auth from 'dashboard/api/auth';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';
import SidebarProfileMenuAccountSwitch from './SidebarProfileMenuAccountSwitch.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSeparator,
  DropdownItem,
} from 'next/dropdown-menu/base';
import CustomBrandPolicyWrapper from '../../components/CustomBrandPolicyWrapper.vue';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const emit = defineEmits([
  'close',
  'openKeyShortcutModal',
  'showCreateAccountModal',
]);

defineOptions({
  inheritAttrs: false,
});

const { t } = useI18n();

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const menuItems = computed(() => {
  return [
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS'),
      icon: 'i-lucide-keyboard',
      click: () => {
        emit('openKeyShortcutModal');
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.PROFILE_SETTINGS'),
      icon: 'i-lucide-user-pen',
      link: { name: 'profile_settings_index' },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.APPEARANCE'),
      icon: 'i-lucide-palette',
      click: () => {
        const ninja = document.querySelector('ninja-keys');
        ninja.open({ parent: 'appearance_settings' });
      },
    },
    {
      show: currentUser.value.type === 'SuperAdmin',
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE'),
      icon: 'i-lucide-castle',
      link: '/super_admin',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.LOGOUT'),
      icon: 'i-lucide-power',
      click: Auth.logout,
    },
  ];
});

const allowedMenuItems = computed(() => {
  return menuItems.value.filter(item => item.show);
});
</script>

<template>
  <DropdownContainer
    class="relative min-w-0"
    :class="isCollapsed ? 'w-auto' : 'w-full'"
    @close="emit('close')"
  >
    <template #trigger="{ toggle, isOpen }">
      <button
        class="flex gap-2.5 items-center text-left cursor-pointer transition-colors"
        :class="[
          isCollapsed
            ? 'justify-center p-1 rounded-lg hover:bg-n-alpha-2'
            : 'w-full p-2 rounded-xl bg-n-alpha-2 outline outline-1 outline-n-weak hover:bg-n-alpha-3',
          { '!bg-n-alpha-3': isOpen },
        ]"
        :title="isCollapsed ? currentUser.available_name : undefined"
        @click="toggle"
      >
        <Avatar
          :size="isCollapsed ? 32 : 36"
          :name="currentUser.available_name"
          :src="currentUser.avatar_url"
          :status="currentUserAvailability"
          class="flex-shrink-0"
        />
        <template v-if="!isCollapsed">
          <div class="flex-1 min-w-0">
            <div
              class="text-sm font-semibold leading-5 truncate text-n-slate-12"
            >
              {{ currentUser.available_name }}
            </div>
            <div class="text-xs truncate text-n-slate-11">
              {{ currentUser.email }}
            </div>
          </div>
          <span
            class="flex-shrink-0 i-lucide-chevrons-up-down size-4 text-n-slate-10"
          />
        </template>
      </button>
    </template>
    <DropdownBody class="top-full z-50 mt-2 w-80 ltr:left-0 rtl:right-0">
      <SidebarProfileMenuStatus />
      <SidebarProfileMenuAccountSwitch
        @show-create-account-modal="emit('showCreateAccountModal')"
      />
      <DropdownSeparator />
      <template v-for="item in allowedMenuItems" :key="item.label">
        <CustomBrandPolicyWrapper
          :show-on-custom-branded-instance="item.showOnCustomBrandedInstance"
        >
          <DropdownItem v-if="item.show" v-bind="item" />
        </CustomBrandPolicyWrapper>
      </template>
    </DropdownBody>
  </DropdownContainer>
</template>
