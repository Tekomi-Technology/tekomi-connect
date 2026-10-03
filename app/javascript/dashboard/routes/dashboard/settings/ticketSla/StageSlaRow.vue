<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import DurationInput from 'dashboard/components-next/input/DurationInput.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const props = defineProps({
  stage: { type: Object, required: true },
  isLast: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const ADVANCE_FIELD = 'description';

const hasSla = ref(false);
const thresholdMinutes = ref(null);
const unit = ref(DURATION_UNITS.MINUTES);
const warningPercent = ref(80);
const autoAdvance = ref(false);

// Picks the largest unit the threshold divides into cleanly, so 1440 reads as "1 day".
const unitFor = minutes => {
  if (!minutes) return DURATION_UNITS.MINUTES;
  if (minutes % (24 * 60) === 0) return DURATION_UNITS.DAYS;
  if (minutes % 60 === 0) return DURATION_UNITS.HOURS;
  return DURATION_UNITS.MINUTES;
};

const resetFromStage = () => {
  hasSla.value = !!props.stage.sla;
  thresholdMinutes.value = props.stage.sla?.thresholdMinutes ?? null;
  warningPercent.value = props.stage.sla?.warningThresholdPercent ?? 80;
  unit.value = unitFor(thresholdMinutes.value);
  autoAdvance.value = (props.stage.autoAdvanceFields || []).includes(
    ADVANCE_FIELD
  );
};

watch(() => props.stage, resetFromStage, { immediate: true, deep: true });

const isValid = computed(() => {
  if (!hasSla.value) return true;
  return (
    thresholdMinutes.value > 0 &&
    warningPercent.value > 0 &&
    warningPercent.value < 100
  );
});

const isDirty = computed(() => {
  const sla = props.stage.sla;
  const savedAdvance = (props.stage.autoAdvanceFields || []).includes(
    ADVANCE_FIELD
  );
  if (autoAdvance.value !== savedAdvance) return true;
  if (hasSla.value !== !!sla) return true;
  if (!hasSla.value) return false;
  return (
    thresholdMinutes.value !== sla.thresholdMinutes ||
    warningPercent.value !== sla.warningThresholdPercent
  );
});

const save = () => {
  if (!isValid.value) return;
  emit('save', {
    stageId: props.stage.id,
    autoAdvanceFields: autoAdvance.value ? [ADVANCE_FIELD] : [],
    sla: hasSla.value
      ? {
          thresholdMinutes: thresholdMinutes.value,
          warningThresholdPercent: warningPercent.value,
        }
      : { thresholdMinutes: null },
  });
};
</script>

<template>
  <div class="flex flex-col gap-3 px-4 py-4 border-b border-n-weak last:border-b-0">
    <div class="flex items-center gap-2">
      <span
        class="flex-shrink-0 rounded-sm size-2.5"
        :style="{ backgroundColor: stage.color }"
      />
      <span class="font-medium text-n-slate-12">{{ stage.name }}</span>
      <Switch v-model="hasSla" class="ltr:ml-auto rtl:mr-auto" />
      <span class="text-sm text-n-slate-11">
        {{ t('TICKET_SLA.STAGE.TRACK') }}
      </span>
    </div>

    <div v-if="hasSla" class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKET_SLA.STAGE.THRESHOLD') }}
        </span>
        <DurationInput
          v-model="thresholdMinutes"
          v-model:unit="unit"
          :min="1"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKET_SLA.STAGE.WARNING_PERCENT') }}
        </span>
        <Input
          v-model.number="warningPercent"
          type="number"
          min="1"
          max="99"
          :message="
            isValid ? '' : t('TICKET_SLA.STAGE.WARNING_PERCENT_ERROR')
          "
          :message-type="isValid ? 'info' : 'error'"
        />
      </div>
    </div>

    <label
      v-if="!isLast"
      class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-11"
    >
      <Switch v-model="autoAdvance" />
      {{ t('TICKET_SLA.STAGE.AUTO_ADVANCE') }}
    </label>

    <div v-if="isDirty" class="flex justify-end gap-2">
      <Button
        :label="t('TICKET_SLA.STAGE.CANCEL')"
        color="slate"
        variant="ghost"
        size="sm"
        @click="resetFromStage"
      />
      <Button
        :label="t('TICKET_SLA.STAGE.SAVE')"
        size="sm"
        :disabled="!isValid"
        :is-loading="isSaving"
        @click="save"
      />
    </div>
  </div>
</template>
