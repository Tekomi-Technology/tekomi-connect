<script setup>
import { computed, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const contactGetter = useMapGetter('contacts/getContact');
const contact = computed(() => contactGetter.value(props.contactId));
const additionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const perfexId = computed(
  () => additionalAttributes.value.external?.perfex_contact_id
);
const crmInfo = computed(() => additionalAttributes.value.crm || {});
const hasFailed = computed(
  () => !!crmInfo.value.match_failed_at && !perfexId.value
);

const isLoading = ref(false);

const reload = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('contacts/matchCrm', props.contactId);
  } catch (error) {
    useAlert(error.message);
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="perfexId">
      <p class="text-sm font-medium text-n-slate-12">
        {{ crmInfo.name }}
      </p>
      <p class="text-xs text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.USERID_LABEL') }}: {{ perfexId }}
      </p>
    </div>
    <div v-else>
      <p v-if="hasFailed" class="mb-2 text-sm text-n-ruby-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.NOT_FOUND') }}
      </p>
      <NextButton
        faded
        slate
        size="sm"
        :is-loading="isLoading"
        :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.RELOAD')"
        @click="reload"
      />
    </div>
  </div>
</template>
