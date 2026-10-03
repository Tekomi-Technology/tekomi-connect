<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsHeader from './SettingsHeader.vue';
const props = defineProps({
  headerTitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  keepAlive: { type: Boolean, default: true },
  showBackButton: { type: Boolean, default: false },
  backUrl: { type: [String, Object], default: '' },
});

const { t } = useI18n();

const showSettingsHeader = computed(
  () => props.headerTitle || props.icon || props.showBackButton
);
</script>

<template>
  <div class="flex flex-col w-full h-full m-0 bg-n-background">
    <div v-if="showSettingsHeader" class="px-4 pt-6 pb-2">
      <SettingsHeader
        :icon="icon"
        :header-title="t(headerTitle)"
        :show-back-button="showBackButton"
        :back-url="backUrl"
        class="z-20 w-full mx-auto max-w-7xl"
      />
    </div>

    <router-view v-slot="{ Component }" class="px-4 overflow-hidden">
      <component :is="Component" v-if="!keepAlive" :key="$route.fullPath" />
      <keep-alive v-else>
        <component :is="Component" :key="$route.fullPath" />
      </keep-alive>
    </router-view>
  </div>
</template>
