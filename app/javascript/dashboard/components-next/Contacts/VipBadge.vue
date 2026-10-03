<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <span
    v-tooltip.top="t('CONTACT_PANEL.VIP.BADGE')"
    class="flex-shrink-0 i-ph-star-fill size-3.5 text-n-amber-9"
    :aria-label="t('CONTACT_PANEL.VIP.BADGE')"
    role="img"
  />
</template>
