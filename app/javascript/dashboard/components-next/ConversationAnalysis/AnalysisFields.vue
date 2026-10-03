<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { toList } from './constants';

defineProps({
  items: {
    type: Array,
    required: true,
  },
});

const LONG_TEXT_LENGTH = 120;

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const expandedKeys = ref([]);

const isLong = value => !Array.isArray(value) && value.length > LONG_TEXT_LENGTH;
const isExpanded = key => expandedKeys.value.includes(key);
const toggle = key => {
  expandedKeys.value = isExpanded(key)
    ? expandedKeys.value.filter(item => item !== key)
    : [...expandedKeys.value, key];
};

const conversationPath = id =>
  frontendURL(conversationUrl({ accountId: accountId.value, id }));
</script>

<template>
  <dl class="grid grid-cols-[6.5rem_1fr] gap-x-3 gap-y-2.5 m-0">
    <template v-for="item in items" :key="item.key">
      <dt class="text-sm text-n-slate-10">{{ item.label }}</dt>
      <dd class="flex flex-col min-w-0 gap-0.5 m-0 text-sm text-n-slate-12">
        <ul
          v-if="Array.isArray(item.value)"
          class="flex flex-col gap-0.5 m-0 ltr:pl-4 rtl:pr-4 list-disc"
        >
          <li v-for="(entry, index) in toList(item.value)" :key="index">
            {{ entry }}
          </li>
        </ul>
        <span
          v-else
          class="break-words"
          :class="{ 'line-clamp-3': isLong(item.value) && !isExpanded(item.key) }"
        >
          {{ item.value }}
        </span>
        <span
          v-if="isLong(item.value) || item.conversationId"
          class="flex items-center gap-2"
        >
          <button
            v-if="isLong(item.value)"
            type="button"
            class="p-0 text-sm bg-transparent border-0 text-n-brand hover:underline"
            @click="toggle(item.key)"
          >
            {{
              isExpanded(item.key)
                ? t('CONVERSATION_ANALYSIS.SHOW_LESS')
                : t('CONVERSATION_ANALYSIS.SHOW_MORE')
            }}
          </button>
          <router-link
            v-if="item.conversationId"
            v-tooltip="
              t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.OPEN_CONVERSATION', {
                id: item.conversationId,
              })
            "
            :to="conversationPath(item.conversationId)"
            class="text-xs text-n-brand hover:underline"
          >
            #{{ item.conversationId }}
          </router-link>
        </span>
      </dd>
    </template>
  </dl>
</template>
