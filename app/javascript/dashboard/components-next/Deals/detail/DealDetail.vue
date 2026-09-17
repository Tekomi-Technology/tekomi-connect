<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import ContactAPI from 'dashboard/api/contacts';
import { useDealsStore } from 'dashboard/stores/deals';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import DealConversations from './DealConversations.vue';
import DealActivities from './DealActivities.vue';
import DealCustomAttributes from './DealCustomAttributes.vue';
import { formatDealDate } from '../constants';

const props = defineProps({
  deal: { type: Object, required: true },
});

const emit = defineEmits(['updated', 'delete']);

const TABS = ['conversations', 'activity'];

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const dealsStore = useDealsStore();
const pipelinesStore = usePipelinesStore();
const agents = useMapGetter('agents/getAgents');

const activeTab = ref('conversations');
const name = ref(props.deal.name);
const value = ref(props.deal.value ?? '');
const contactOptions = ref([]);

const stageOptions = computed(() =>
  pipelinesStore.records.flatMap(pipeline =>
    pipeline.stages.map(stage => ({
      value: stage.id,
      label:
        pipelinesStore.records.length > 1
          ? `${pipeline.name} · ${stage.name}`
          : stage.name,
    }))
  )
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const tabs = computed(() =>
  TABS.map(tab => ({
    value: tab,
    label: t(`DEALS.DETAIL.TABS.${tab.toUpperCase()}`),
  }))
);

const applyChanges = async changes => {
  try {
    emit('updated', await dealsStore.update(props.deal, changes));
  } catch {
    useAlert(t('DEALS.MESSAGES.UPDATE_ERROR'));
  }
};

const commitName = () => {
  if (name.value.trim() && name.value.trim() !== props.deal.name) {
    applyChanges({ name: name.value.trim() });
  } else {
    name.value = props.deal.name;
  }
};

const commitValue = () => {
  const nextValue = value.value === '' ? null : Number(value.value);
  if (nextValue !== props.deal.value) applyChanges({ value: nextValue });
};

const changeStage = async stageId => {
  if (!stageId || stageId === props.deal.stageId) return;
  try {
    emit(
      'updated',
      await dealsStore.move(props.deal, {
        stageId,
        position: props.deal.position,
      })
    );
  } catch {
    useAlert(t('DEALS.MESSAGES.UPDATE_ERROR'));
  }
};

const searchContacts = debounce(async query => {
  const { data } = await ContactAPI.search(query);
  contactOptions.value = data.payload.map(contact => ({
    value: contact.id,
    label: contact.name,
  }));
}, 300);

watch(
  () => props.deal,
  deal => {
    name.value = deal.name;
    value.value = deal.value ?? '';
  }
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex items-start gap-2">
      <Input
        v-model="name"
        class="flex-1"
        custom-input-class="text-lg font-medium"
        @blur="commitName"
        @enter="commitName"
      />
      <Button
        icon="i-lucide-trash"
        color="ruby"
        variant="ghost"
        size="sm"
        @click="emit('delete', deal)"
      />
    </div>

    <dl class="grid grid-cols-[9rem_1fr] items-center gap-x-4 gap-y-3 text-sm">
      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.STAGE') }}</dt>
      <dd class="mb-0">
        <ComboBox
          :model-value="deal.stageId"
          :options="stageOptions"
          @update:model-value="changeStage"
        />
      </dd>

      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.VALUE') }}</dt>
      <dd class="mb-0">
        <Input
          v-model="value"
          type="number"
          min="0"
          :placeholder="t('DEALS.FORM.VALUE_PLACEHOLDER')"
          @blur="commitValue"
          @enter="commitValue"
        />
      </dd>

      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.ASSIGNEE') }}</dt>
      <dd class="mb-0">
        <ComboBox
          :model-value="deal.assignee?.id || ''"
          :options="agentOptions"
          :display-label="deal.assignee?.name"
          :placeholder="t('DEALS.FORM.ASSIGNEE_PLACEHOLDER')"
          @update:model-value="applyChanges({ assigneeId: $event || null })"
        />
      </dd>

      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.CONTACT') }}</dt>
      <dd class="flex items-center gap-1 mb-0">
        <ComboBox
          :model-value="deal.contact?.id || ''"
          :options="contactOptions"
          :display-label="deal.contact?.name"
          :placeholder="t('DEALS.FORM.CONTACT_PLACEHOLDER')"
          :search-placeholder="t('DEALS.FORM.CONTACT_SEARCH_PLACEHOLDER')"
          use-api-results
          @search="searchContacts"
          @update:model-value="applyChanges({ contactId: $event || null })"
        />
        <router-link
          v-if="deal.contact"
          :to="
            accountScopedRoute('contacts_edit', { contactId: deal.contact.id })
          "
        >
          <Button
            icon="i-lucide-external-link"
            color="slate"
            variant="ghost"
            size="sm"
          />
        </router-link>
      </dd>

      <template v-if="deal.company">
        <dt class="text-n-slate-11">{{ t('DEALS.DETAIL.COMPANY') }}</dt>
        <dd class="mb-0">
          <router-link
            :to="
              accountScopedRoute('companies_dashboard_show', {
                companyId: deal.company.id,
              })
            "
            class="text-n-blue-11 hover:underline"
          >
            {{ deal.company.name }}
          </router-link>
        </dd>
      </template>

      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.EXPECTED_CLOSE_DATE') }}</dt>
      <dd class="mb-0">
        <Input
          :model-value="deal.expectedCloseDate || ''"
          type="date"
          @update:model-value="applyChanges({ expectedCloseDate: $event || null })"
        />
      </dd>

      <template v-if="deal.closedAt">
        <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.CLOSED_AT') }}</dt>
        <dd class="mb-0 text-n-slate-12">{{ formatDealDate(deal.closedAt) }}</dd>
      </template>

      <dt class="text-n-slate-11">{{ t('DEALS.FIELDS.CREATED_AT') }}</dt>
      <dd class="mb-0 text-n-slate-12">{{ formatDealDate(deal.createdAt) }}</dd>
    </dl>

    <DealCustomAttributes :deal="deal" @updated="emit('updated', $event)" />

    <div class="flex flex-col gap-4">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="TABS.indexOf(activeTab)"
        class="w-full [&>button]:w-full bg-n-alpha-black2"
        @tab-changed="activeTab = $event.value"
      />
      <DealConversations
        v-if="activeTab === 'conversations'"
        :deal="deal"
      />
      <DealActivities v-else :deal="deal" />
    </div>
  </div>
</template>
