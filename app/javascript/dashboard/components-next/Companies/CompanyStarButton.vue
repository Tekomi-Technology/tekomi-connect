<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useCompaniesStore } from 'dashboard/stores/companies';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  company: { type: Object, required: true },
});

const { t } = useI18n();
const companiesStore = useCompaniesStore();
const isUpdating = ref(false);

const toggleStar = async () => {
  const vip = !props.company.vip;
  isUpdating.value = true;
  try {
    await companiesStore.update({ id: props.company.id, vip });
    useAlert(t(vip ? 'COMPANIES.STAR.MARKED' : 'COMPANIES.STAR.UNMARKED'));
  } catch {
    useAlert(t('COMPANIES.STAR.ERROR'));
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <Button
    v-tooltip.top-end="
      t(company.vip ? 'COMPANIES.STAR.UNMARK' : 'COMPANIES.STAR.MARK')
    "
    :icon="company.vip ? 'i-ph-star-fill' : 'i-ph-star'"
    :color="company.vip ? 'amber' : 'slate'"
    faded
    xs
    :is-loading="isUpdating"
    :disabled="isUpdating"
    @click="toggleStar"
  />
</template>
