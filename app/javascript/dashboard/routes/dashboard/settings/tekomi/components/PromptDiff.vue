<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { lineDiff } from '../helpers/lineDiff';

const props = defineProps({
  defaultBody: {
    type: String,
    default: '',
  },
  accountBody: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();

const diff = computed(() => lineDiff(props.defaultBody, props.accountBody));

const leftClass = row =>
  row.kind === 'removed' || row.kind === 'changed'
    ? 'bg-n-ruby-2 text-n-ruby-12'
    : 'text-n-slate-12';

const rightClass = row =>
  row.kind === 'added' || row.kind === 'changed'
    ? 'bg-n-teal-2 text-n-teal-12'
    : 'text-n-slate-12';
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-xs text-n-slate-11">
      <span class="font-medium text-n-teal-11">
        {{ t('TEKOMI_SETTINGS.PROMPTS.DIFF.ADDED', { count: diff.addedCount }) }}
      </span>
      ·
      <span class="font-medium text-n-ruby-11">
        {{
          t('TEKOMI_SETTINGS.PROMPTS.DIFF.REMOVED', {
            count: diff.removedCount,
          })
        }}
      </span>
      ·
      {{ t('TEKOMI_SETTINGS.PROMPTS.DIFF.KEPT', { count: diff.keptCount }) }}
    </p>

    <div class="overflow-hidden border rounded-lg border-n-weak">
      <div class="grid grid-cols-2 text-xs font-medium border-b border-n-weak">
        <div class="px-3 py-2 border-r border-n-weak text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.PROMPTS.DIFF.LEFT_TITLE') }}
        </div>
        <div class="px-3 py-2 text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.PROMPTS.DIFF.RIGHT_TITLE') }}
        </div>
      </div>

      <div class="overflow-auto max-h-[27rem]">
        <div
          v-for="(row, index) in diff.rows"
          :key="index"
          class="grid grid-cols-2"
        >
          <div class="flex border-r border-n-weak" :class="leftClass(row)">
            <span
              class="pr-2 font-mono text-xs leading-5 text-right select-none shrink-0 w-11 text-n-slate-9"
            >
              {{ row.leftNumber }}
            </span>
            <span
              class="flex-grow min-w-0 px-2 font-mono text-xs leading-5 whitespace-pre-wrap break-words"
            >
              {{ row.leftText }}
            </span>
          </div>
          <div class="flex" :class="rightClass(row)">
            <span
              class="pr-2 font-mono text-xs leading-5 text-right select-none shrink-0 w-11 text-n-slate-9"
            >
              {{ row.rightNumber }}
            </span>
            <span
              class="flex-grow min-w-0 px-2 font-mono text-xs leading-5 whitespace-pre-wrap break-words"
            >
              {{ row.rightText }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
