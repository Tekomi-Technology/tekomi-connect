<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Button from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';

const emit = defineEmits(['showCreateAccountModal']);

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');
const userAccounts = useMapGetter('getUserAccounts');

const showAccountSwitcher = computed(() => userAccounts.value.length > 1);

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  window.location.href = `/app/accounts/${newId}/home`;
};

const emitNewAccount = () => {
  emit('showCreateAccountModal');
};
</script>

<template>
  <template v-if="showAccountSwitcher">
    <DropdownItem preserve-open class="gap-1">
      <div class="flex-grow flex items-center gap-1 min-w-0">
        {{ t('SIDEBAR_ITEMS.SWITCH_ACCOUNT') }}
      </div>
      <DropdownContainer class="shrink-0">
        <template #trigger="{ toggle }">
          <Button
            size="sm"
            color="slate"
            variant="faded"
            icon="i-lucide-chevron-down"
            trailing-icon
            @click="toggle"
          >
            <span class="truncate max-w-[7rem]">{{ currentAccount.name }}</span>
          </Button>
        </template>
        <DropdownBody class="min-w-64 z-20">
          <DropdownSection>
            <DropdownItem
              v-for="account in sortedCurrentUserAccounts"
              :id="`account-${account.id}`"
              :key="account.id"
              class="cursor-pointer"
              @click="onChangeAccount(account.id)"
            >
              <template #label>
                <div
                  :for="account.name"
                  class="text-left rtl:text-right flex gap-2 items-center"
                >
                  <span
                    class="text-n-slate-12 max-w-36 truncate min-w-0"
                    :title="account.name"
                  >
                    {{ account.name }}
                  </span>
                  <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
                  <span
                    class="text-n-slate-11 max-w-24 truncate capitalize"
                    :title="account.name"
                  >
                    {{
                      account.custom_role_id
                        ? account.custom_role.name
                        : account.role
                    }}
                  </span>
                </div>
                <Icon
                  v-show="account.id === accountId"
                  icon="i-lucide-check"
                  class="text-n-teal-11 size-5"
                />
              </template>
            </DropdownItem>
          </DropdownSection>
          <DropdownItem v-if="globalConfig.createNewAccountFromDashboard">
            <Button
              color="slate"
              variant="faded"
              class="w-full"
              size="sm"
              @click="emitNewAccount"
            >
              {{ t('CREATE_ACCOUNT.NEW_ACCOUNT') }}
            </Button>
          </DropdownItem>
        </DropdownBody>
      </DropdownContainer>
    </DropdownItem>
  </template>
</template>
