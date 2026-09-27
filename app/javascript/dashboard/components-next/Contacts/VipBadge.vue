<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <span
    class="inline-flex items-center flex-shrink-0 gap-0.5 px-1.5 py-0.5 rounded-full text-[11px] font-semibold uppercase leading-none bg-n-amber-3 text-n-amber-11"
  >
    <span class="i-lucide-crown size-3" />
    {{ t('CONTACT_PANEL.VIP.BADGE') }}
  </span>
</template>
