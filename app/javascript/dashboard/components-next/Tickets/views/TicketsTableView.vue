<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketFieldValue from '../TicketFieldValue.vue';
import { useTicketFields } from '../useTicketFields';

const props = defineProps({
  tickets: { type: Array, required: true },
  stages: { type: Array, required: true },
  fields: { type: Array, required: true },
  hasMore: { type: Boolean, default: false },
  isFetching: { type: Boolean, default: false },
  isFetchingMore: { type: Boolean, default: false },
});

const emit = defineEmits(['loadMore', 'open']);

const { fieldLabel } = useTicketFields();

const stagesById = computed(() =>
  Object.fromEntries(props.stages.map(stage => [stage.id, stage]))
);

const { t } = useI18n();

// The title always leads, then one column per field the view has switched on.
const headers = computed(() => [
  t('TICKETS.FIELDS.TITLE'),
  ...props.fields.map(field => fieldLabel(field)),
]);
</script>

<template>
  <div class="flex flex-col gap-3 px-6 pb-6 overflow-y-auto">
    <div v-if="isFetching" class="flex justify-center py-10">
      <Spinner />
    </div>
    <template v-else>
      <BaseTable
        :headers="headers"
        :items="tickets"
        :no-data-message="$t('TICKETS.EMPTY_STATE')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="ticket in items"
            :key="ticket.id"
            :item="ticket"
            class="cursor-pointer"
            @click="emit('open', ticket)"
          >
            <template #default>
              <BaseTableCell>
                <span class="truncate text-body-main text-n-slate-12">
                  {{ ticket.title }}
                </span>
              </BaseTableCell>
              <BaseTableCell
                v-for="field in fields"
                :key="field"
                class="w-44"
              >
                <TicketFieldValue
                  :ticket="ticket"
                  :field="field"
                  :stage="stagesById[ticket.stageId]"
                  class="text-body-main text-n-slate-11"
                />
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
      <Button
        v-if="hasMore"
        :label="$t('TICKETS.LOAD_MORE')"
        color="slate"
        variant="ghost"
        size="sm"
        :is-loading="isFetchingMore"
        @click="emit('loadMore')"
      />
    </template>
  </div>
</template>
