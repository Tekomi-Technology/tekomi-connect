<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import {
  addDays,
  addMonths,
  addWeeks,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameMonth,
  isToday,
  startOfMonth,
  startOfWeek,
} from 'date-fns';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DealCard from '../DealCard.vue';
import { CALENDAR_MODES, toDate } from '../constants';

const props = defineProps({
  deals: { type: Array, required: true },
  undatedDeals: { type: Array, required: true },
  stages: { type: Array, required: true },
  fields: { type: Array, required: true },
  settings: { type: Object, default: () => ({}) },
  isFetching: { type: Boolean, default: false },
});

const emit = defineEmits(['rangeChange', 'update', 'create', 'open']);

const WEEK_OPTIONS = { weekStartsOn: 1 };
const MONTH_VISIBLE_DEALS = 3;
const DATE_KEY_FORMAT = 'yyyy-MM-dd';
const FIELD_ATTRIBUTES = {
  expected_close_date: 'expectedCloseDate',
  closed_at: 'closedAt',
  created_at: 'createdAt',
};

const { t } = useI18n();
const mode = ref('month');
const cursor = ref(new Date());
const expandedDays = ref([]);

const dateField = computed(
  () => props.settings.calendar_field || 'expected_close_date'
);
const isEditable = computed(() => dateField.value === 'expected_close_date');
const cardFields = computed(() =>
  props.fields.filter(field => field !== dateField.value)
);
const stagesById = computed(() =>
  Object.fromEntries(props.stages.map(stage => [stage.id, stage]))
);

const range = computed(() => {
  if (mode.value === 'day') return { start: cursor.value, end: cursor.value };
  if (mode.value === 'week') {
    return {
      start: startOfWeek(cursor.value, WEEK_OPTIONS),
      end: endOfWeek(cursor.value, WEEK_OPTIONS),
    };
  }
  return {
    start: startOfWeek(startOfMonth(cursor.value), WEEK_OPTIONS),
    end: endOfWeek(endOfMonth(cursor.value), WEEK_OPTIONS),
  };
});

const days = computed(() => eachDayOfInterval(range.value));

const title = computed(() => {
  if (mode.value === 'day') return format(cursor.value, 'dd/MM/yyyy');
  if (mode.value === 'week') {
    return `${format(range.value.start, 'dd/MM')} – ${format(range.value.end, 'dd/MM/yyyy')}`;
  }
  return format(cursor.value, 'MM/yyyy');
});

const dealsByDay = computed(() => {
  const attribute = FIELD_ATTRIBUTES[dateField.value];
  return props.deals.reduce((groups, deal) => {
    if (!deal[attribute]) return groups;
    const key = format(toDate(deal[attribute]), DATE_KEY_FORMAT);
    groups[key] = [...(groups[key] || []), deal];
    return groups;
  }, {});
});

const dayKey = day => format(day, DATE_KEY_FORMAT);

const visibleDeals = day => {
  const dayDeals = dealsByDay.value[dayKey(day)] || [];
  if (mode.value !== 'month' || expandedDays.value.includes(dayKey(day))) {
    return dayDeals;
  }
  return dayDeals.slice(0, MONTH_VISIBLE_DEALS);
};

const hiddenCount = day =>
  (dealsByDay.value[dayKey(day)] || []).length - visibleDeals(day).length;

const expandDay = day => {
  expandedDays.value = [...expandedDays.value, dayKey(day)];
};

const shift = direction => {
  const shifters = { month: addMonths, week: addWeeks, day: addDays };
  cursor.value = shifters[mode.value](cursor.value, direction);
};

const onDayChange = (day, { added }) => {
  if (!added) return;
  emit('update', {
    deal: added.element,
    changes: { expectedCloseDate: dayKey(day) },
  });
};

const onUndatedChange = ({ added }) => {
  if (!added) return;
  emit('update', {
    deal: added.element,
    changes: { expectedCloseDate: null },
  });
};

const createOnDay = day => {
  emit('create', { expectedCloseDate: dayKey(day) });
};

watch(
  range,
  ({ start, end }) => {
    expandedDays.value = [];
    emit('rangeChange', {
      dateField: dateField.value,
      dateFrom: dayKey(start),
      dateTo: dayKey(end),
    });
  },
  { immediate: true }
);

watch(dateField, () => {
  emit('rangeChange', {
    dateField: dateField.value,
    dateFrom: dayKey(range.value.start),
    dateTo: dayKey(range.value.end),
  });
});
</script>

<template>
  <div class="flex flex-col h-full min-h-0 gap-3 px-6 pb-6">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex items-center gap-1">
        <Button
          icon="i-lucide-chevron-left"
          color="slate"
          variant="ghost"
          size="sm"
          @click="shift(-1)"
        />
        <Button
          :label="t('DEALS.CALENDAR.TODAY')"
          color="slate"
          variant="faded"
          size="sm"
          @click="cursor = new Date()"
        />
        <Button
          icon="i-lucide-chevron-right"
          color="slate"
          variant="ghost"
          size="sm"
          @click="shift(1)"
        />
        <span class="text-sm font-medium ltr:ml-2 rtl:mr-2 text-n-slate-12">
          {{ title }}
        </span>
      </div>
      <div class="flex items-center gap-1 p-0.5 rounded-lg bg-n-alpha-1">
        <Button
          v-for="calendarMode in CALENDAR_MODES"
          :key="calendarMode"
          :label="t(`DEALS.CALENDAR.MODES.${calendarMode.toUpperCase()}`)"
          :color="mode === calendarMode ? 'blue' : 'slate'"
          :variant="mode === calendarMode ? 'faded' : 'ghost'"
          size="xs"
          @click="mode = calendarMode"
        />
      </div>
    </div>

    <div v-if="isFetching" class="flex justify-center py-10">
      <Spinner />
    </div>
    <div v-else class="flex flex-1 min-h-0 gap-3">
      <div class="flex flex-col flex-1 min-w-0 min-h-0 overflow-auto">
        <div
          v-if="mode !== 'day'"
          class="grid grid-cols-7 text-xs font-medium border-b min-w-[42rem] text-n-slate-11 border-n-weak"
        >
          <span
            v-for="day in days.slice(0, 7)"
            :key="dayKey(day)"
            class="px-2 py-1"
          >
            {{ format(day, 'EEE') }}
          </span>
        </div>
        <div
          class="grid flex-1 border-n-weak ltr:border-l rtl:border-r"
          :class="mode === 'day' ? 'grid-cols-1' : 'grid-cols-7 min-w-[42rem]'"
        >
          <div
            v-for="day in days"
            :key="dayKey(day)"
            class="flex flex-col gap-1 p-1.5 border-b group/day ltr:border-r rtl:border-l border-n-weak"
            :class="[
              mode === 'month' ? 'min-h-32' : 'min-h-96',
              { 'bg-n-alpha-1': mode === 'month' && !isSameMonth(day, cursor) },
            ]"
          >
            <div class="flex items-center justify-between">
              <span
                class="px-1.5 text-xs rounded-md"
                :class="isToday(day) ? 'bg-n-brand text-white' : 'text-n-slate-11'"
              >
                {{ format(day, mode === 'month' ? 'd' : 'EEE dd/MM') }}
              </span>
              <Button
                v-if="isEditable"
                icon="i-lucide-plus"
                color="slate"
                variant="ghost"
                size="xs"
                class="invisible group-hover/day:visible"
                @click="createOnDay(day)"
              />
            </div>
            <Draggable
              :model-value="visibleDeals(day)"
              :group="{ name: 'calendar', pull: isEditable, put: isEditable }"
              :disabled="!isEditable"
              item-key="id"
              ghost-class="opacity-40"
              animation="150"
              class="flex flex-col flex-1 gap-1"
              @change="onDayChange(day, $event)"
            >
              <template #item="{ element }">
                <DealCard
                  :deal="element"
                  :fields="cardFields"
                  :stages-by-id="stagesById"
                  @click="emit('open', element)"
                />
              </template>
            </Draggable>
            <button
              v-if="hiddenCount(day) > 0"
              type="button"
              class="self-start px-1.5 text-xs rounded-md text-n-slate-11 hover:bg-n-alpha-2"
              @click="expandDay(day)"
            >
              {{ t('DEALS.CALENDAR.MORE', { count: hiddenCount(day) }) }}
            </button>
          </div>
        </div>
      </div>

      <aside
        v-if="isEditable"
        class="flex-col flex-shrink-0 hidden w-64 min-h-0 gap-2 p-2 md:flex rounded-xl bg-n-alpha-1"
      >
        <span class="px-1 text-xs font-medium uppercase text-n-slate-11">
          {{ t('DEALS.CALENDAR.UNDATED', { count: undatedDeals.length }) }}
        </span>
        <Draggable
          :model-value="undatedDeals"
          group="calendar"
          item-key="id"
          ghost-class="opacity-40"
          animation="150"
          class="flex flex-col flex-1 min-h-0 gap-2 overflow-y-auto"
          @change="onUndatedChange"
        >
          <template #item="{ element }">
            <DealCard
              :deal="element"
              :fields="cardFields"
              :stages-by-id="stagesById"
              @click="emit('open', element)"
            />
          </template>
        </Draggable>
      </aside>
    </div>
  </div>
</template>
