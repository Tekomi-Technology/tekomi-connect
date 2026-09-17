<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import DealsAPI from 'dashboard/api/deals';
import { camelizeDeal, useDealsStore } from 'dashboard/stores/deals';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DealFormDialog from './DealFormDialog.vue';
import { formatVND } from './constants';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contact: { type: Object, default: null },
});

const { t } = useI18n();
const router = useRouter();
const dealsStore = useDealsStore();
const pipelinesStore = usePipelinesStore();
const agents = useMapGetter('agents/getAgents');

const linkedDeals = ref([]);
const contactDeals = ref([]);
const isLoading = ref(false);
const dealFormDialogRef = ref(null);

const stages = computed(() =>
  pipelinesStore.records.flatMap(pipeline =>
    pipeline.stages.map(stage => ({
      ...stage,
      name:
        pipelinesStore.records.length > 1
          ? `${pipeline.name} · ${stage.name}`
          : stage.name,
    }))
  )
);
const stagesById = computed(() =>
  Object.fromEntries(stages.value.map(stage => [stage.id, stage]))
);
const otherContactDeals = computed(() => {
  const linkedIds = linkedDeals.value.map(deal => deal.id);
  return contactDeals.value.filter(deal => !linkedIds.includes(deal.id));
});

const loadDeals = async () => {
  isLoading.value = true;
  try {
    const [linkedResponse, contactResponse] = await Promise.all([
      DealsAPI.getByConversation(props.conversationId),
      props.contact?.id ? DealsAPI.getByContact(props.contact.id) : null,
    ]);
    linkedDeals.value = linkedResponse.data.payload.map(camelizeDeal);
    contactDeals.value =
      contactResponse?.data.payload.map(camelizeDeal) || [];
  } catch {
    useAlert(t('DEALS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const linkDeal = async deal => {
  try {
    await DealsAPI.linkConversation(deal.id, props.conversationId);
    await loadDeals();
  } catch {
    useAlert(t('DEALS.DETAIL.CONVERSATIONS.LINK_ERROR'));
  }
};

const unlinkDeal = async deal => {
  try {
    await DealsAPI.unlinkConversation(deal.id, props.conversationId);
    await loadDeals();
  } catch {
    useAlert(t('DEALS.DETAIL.CONVERSATIONS.UNLINK_ERROR'));
  }
};

const openDeal = deal => {
  router.push({ name: 'deals_show', params: { dealId: deal.id } });
};

const openCreateDeal = () => {
  dealFormDialogRef.value?.open({
    contactId: props.contact?.id || '',
    contactName: props.contact?.name || '',
  });
};

const createDeal = async payload => {
  try {
    const deal = await dealsStore.create(payload);
    await DealsAPI.linkConversation(deal.id, props.conversationId);
    dealFormDialogRef.value?.close();
    useAlert(t('DEALS.FORM.MESSAGES.SUCCESS'));
    await loadDeals();
  } catch {
    useAlert(t('DEALS.FORM.MESSAGES.ERROR'));
  }
};

watch(() => [props.conversationId, props.contact?.id], loadDeals);

onMounted(() => {
  loadDeals();
  if (!pipelinesStore.records.length) pipelinesStore.fetch();
});
</script>

<template>
  <div class="flex flex-col gap-3 px-2 pb-2">
    <div v-if="isLoading" class="flex justify-center py-3">
      <Spinner :size="20" />
    </div>
    <template v-else>
      <p
        v-if="!linkedDeals.length && !otherContactDeals.length"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('DEALS.CONVERSATION.EMPTY') }}
      </p>
      <template
        v-for="section in [
          { key: 'linked', deals: linkedDeals, linked: true },
          { key: 'contact', deals: otherContactDeals, linked: false },
        ]"
        :key="section.key"
      >
        <div v-if="section.deals.length" class="flex flex-col gap-2">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t(`DEALS.CONVERSATION.${section.key.toUpperCase()}`) }}
          </span>
          <div
            v-for="deal in section.deals"
            :key="deal.id"
            class="flex items-center gap-2 p-2 text-sm rounded-lg bg-n-alpha-1"
          >
            <button
              type="button"
              class="flex flex-col flex-1 min-w-0 gap-0.5 text-start"
              @click="openDeal(deal)"
            >
              <span class="font-medium truncate text-n-slate-12">
                {{ deal.name }}
              </span>
              <span class="flex items-center gap-1.5 truncate text-n-slate-11">
                <span
                  v-if="stagesById[deal.stageId]"
                  class="flex-shrink-0 rounded-sm size-2"
                  :style="{ backgroundColor: stagesById[deal.stageId].color }"
                />
                {{ stagesById[deal.stageId]?.name }}
                <template v-if="deal.value !== null">
                  · {{ formatVND(deal.value) }}
                </template>
              </span>
            </button>
            <Button
              :icon="section.linked ? 'i-lucide-unlink' : 'i-lucide-link'"
              color="slate"
              variant="ghost"
              size="xs"
              @click="section.linked ? unlinkDeal(deal) : linkDeal(deal)"
            />
          </div>
        </div>
      </template>
    </template>
    <Button
      :label="t('DEALS.CONVERSATION.CREATE')"
      icon="i-lucide-plus"
      color="slate"
      variant="faded"
      size="sm"
      @click="openCreateDeal"
    />
    <DealFormDialog
      ref="dealFormDialogRef"
      :stages="stages"
      :agents="agents"
      :is-loading="dealsStore.uiFlags.isCreating"
      @create="createDeal"
    />
  </div>
</template>
