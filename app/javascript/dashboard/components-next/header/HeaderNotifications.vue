<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import wootConstants from 'dashboard/constants/globals';

import Popover from 'dashboard/components-next/popover/Popover.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InboxCard from 'dashboard/components-next/Inbox/InboxCard.vue';
import IntersectionObserver from 'dashboard/components/IntersectionObserver.vue';

const MAX_BADGE_COUNT = 9;

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const popoverRef = ref(null);
const notificationList = ref(null);
const page = ref(1);

const meta = useMapGetter('notifications/getMeta');
const uiFlags = useMapGetter('notifications/getUIFlags');
const records = useMapGetter('notifications/getFilteredNotificationsV4');
const inboxById = useMapGetter('inboxes/getInboxById');

const filters = computed(() => ({
  page: page.value,
  sortOrder: wootConstants.INBOX_SORT_BY.NEWEST,
}));

const notifications = computed(() => records.value(filters.value));

const unreadCount = computed(() => meta.value.unreadCount || 0);

const badgeLabel = computed(() =>
  unreadCount.value > MAX_BADGE_COUNT
    ? `${MAX_BADGE_COUNT}+`
    : String(unreadCount.value)
);

const infiniteLoaderOptions = computed(() => ({
  root: notificationList.value,
  rootMargin: '100px 0px 100px 0px',
}));

const canLoadMore = computed(
  () => !uiFlags.value.isAllNotificationsLoaded && !uiFlags.value.isFetching
);

const showEmptyState = computed(
  () => !uiFlags.value.isFetching && !notifications.value.length
);

const fetchNotifications = () => {
  page.value = 1;
  store.dispatch('notifications/clear');
  store.dispatch('notifications/index', filters.value);
};

const loadMoreNotifications = () => {
  page.value += 1;
  store.dispatch('notifications/index', filters.value);
};

const markAllRead = async () => {
  await store.dispatch('notifications/readAll');
  useAlert(t('INBOX.ALERTS.MARK_ALL_READ'));
};

const openConversation = async notification => {
  const { id, primaryActorId, primaryActorType, primaryActor } = notification;

  if (!notification.readAt) {
    await store.dispatch('notifications/read', {
      id,
      primaryActorId,
      primaryActorType,
      unreadCount: meta.value.unreadCount,
    });
    store.dispatch('notifications/unReadCount');
  }

  popoverRef.value.hide();
  router.push({
    name: 'inbox_conversation',
    params: { conversation_id: primaryActor.id },
  });
};

onMounted(() => store.dispatch('notifications/unReadCount'));
</script>

<template>
  <Popover ref="popoverRef" align="end" @show="fetchNotifications">
    <template #default="{ isOpen }">
      <button
        type="button"
        class="relative grid flex-shrink-0 transition-colors rounded-full size-9 place-items-center text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
        :class="{ 'bg-n-alpha-2 text-n-slate-12': isOpen }"
        :title="t('SIDEBAR.NOTIFICATIONS')"
      >
        <span class="i-lucide-bell size-5" />
        <span
          v-if="unreadCount"
          class="absolute -top-0.5 ltr:-right-1 rtl:-left-1 grid h-[1.125rem] min-w-[1.125rem] place-items-center rounded-full bg-n-ruby-9 px-1 text-xxs font-semibold leading-none text-white ring-2 ring-white dark:ring-n-solid-2"
        >
          {{ badgeLabel }}
        </span>
      </button>
    </template>
    <template #content>
      <div class="flex flex-col w-full md:w-96 max-h-[32rem]">
        <div
          class="flex items-center justify-between flex-shrink-0 gap-2 py-2 border-b ltr:pl-4 rtl:pr-4 ltr:pr-2 rtl:pl-2 border-n-weak"
        >
          <div class="flex items-center min-w-0 gap-2">
            <h2 class="text-sm font-semibold truncate text-n-slate-12">
              {{ t('SIDEBAR.NOTIFICATIONS') }}
            </h2>
            <span
              v-if="unreadCount"
              class="px-1.5 py-0.5 text-xxs font-semibold rounded-full bg-n-ruby-9/10 text-n-ruby-11"
            >
              {{ unreadCount }}
            </span>
          </div>
          <Button
            :label="t('INBOX.MENU_ITEM.MARK_ALL_READ')"
            icon="i-lucide-check-check"
            ghost
            slate
            xs
            :disabled="!unreadCount"
            @click="markAllRead"
          />
        </div>
        <!-- The notification card opens its own context menu outside this popover, which would close it. -->
        <div
          ref="notificationList"
          class="flex flex-col flex-1 min-h-0 px-2 pb-2 overflow-x-hidden overflow-y-auto divide-y divide-n-weak"
          @contextmenu.capture.stop
        >
          <InboxCard
            v-for="notification in notifications"
            :key="notification.id"
            :inbox-item="notification"
            :state-inbox="inboxById(notification.primaryActor?.inboxId)"
            class="rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
            @click="openConversation(notification)"
          />
          <div v-if="uiFlags.isFetching" class="flex justify-center py-4">
            <Spinner class="text-n-brand" />
          </div>
          <div
            v-if="showEmptyState"
            class="flex flex-col items-center gap-2 px-4 py-10 text-n-slate-10"
          >
            <span class="i-lucide-bell-off size-6" />
            <p class="mb-0 text-sm font-medium">
              {{ t('INBOX.LIST.NO_NOTIFICATIONS') }}
            </p>
          </div>
          <IntersectionObserver
            v-if="canLoadMore && notifications.length"
            :options="infiniteLoaderOptions"
            @observed="loadMoreNotifications"
          />
        </div>
      </div>
    </template>
  </Popover>
</template>
