<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();

// Routes that manage filters/pagination via query params opt out of
// query-keyed remounts, else every filter change rebuilds the page.
const routeKey = computed(() =>
  route.meta.reuseOnQueryChange ? route.path : route.fullPath
);
</script>

<template>
  <div
    class="flex flex-col w-full h-full p-6 m-0 overflow-auto no-scrollbar bg-n-background"
  >
    <div class="flex items-start w-full">
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="routeKey" />
        </keep-alive>
        <component :is="Component" v-else :key="routeKey" />
      </router-view>
    </div>
  </div>
</template>
