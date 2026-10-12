<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useTekomiPromptsStore } from 'dashboard/store/tekomi/prompts';

import SettingsShell from './SettingsShell.vue';
import PromptList from './components/PromptList.vue';
import PromptEditor from './components/PromptEditor.vue';
import PromptDiff from './components/PromptDiff.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();

const promptsStore = useTekomiPromptsStore();
const { records, selected, uiFlags } = storeToRefs(promptsStore);

// Edits survive switching between prompts, so a half-written prompt is not
// thrown away by a stray click in the list.
const drafts = reactive({});
const showDiff = ref(false);

const selectedKey = computed(() => route.params.promptKey || '');
const draft = computed({
  get: () => drafts[selectedKey.value] ?? '',
  set: value => {
    drafts[selectedKey.value] = value;
  },
});

const isDirty = computed(
  () => selected.value && draft.value !== selected.value.body
);

const groupLabel = computed(() =>
  selected.value
    ? t(
        `TEKOMI_SETTINGS.GROUPS.${selected.value.group.toUpperCase()}`,
        selected.value.group
      )
    : ''
);

const selectPrompt = key => {
  router.push({
    name: 'tekomi_settings_prompt',
    params: { accountId: accountId.value, promptKey: key },
  });
};

const loadPrompt = async key => {
  if (!key) return;
  showDiff.value = false;
  const detail = await promptsStore.fetchItem(key);
  if (drafts[key] === undefined) drafts[key] = detail.body;
};

const savePrompt = async () => {
  try {
    const detail = await promptsStore.save(selectedKey.value, draft.value);
    drafts[selectedKey.value] = detail.body;
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_ERROR'));
  }
};

const restorePrompt = async () => {
  try {
    const detail = await promptsStore.restore(selectedKey.value);
    drafts[selectedKey.value] = detail.body;
    showDiff.value = false;
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.RESTORE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_ERROR'));
  }
};

watch(selectedKey, key => loadPrompt(key));

onMounted(async () => {
  await promptsStore.fetch();

  if (!selectedKey.value && records.value.length) {
    router.replace({
      name: 'tekomi_settings_prompt',
      params: { accountId: accountId.value, promptKey: records.value[0].key },
    });
    return;
  }

  loadPrompt(selectedKey.value);
});
</script>

<template>
  <SettingsShell :is-loading="uiFlags.isFetchingList">
    <div class="flex flex-wrap items-start gap-4">
      <div class="flex-1 min-w-[16rem] max-w-[21rem]">
        <PromptList
          :records="records"
          :selected-key="selectedKey"
          @select="selectPrompt"
        />
      </div>

      <div
        v-if="selected"
        class="flex flex-col flex-[999] min-w-0 gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1"
      >
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="text-base font-medium text-n-slate-12">
                {{ selected.name }}
              </h2>
              <span
                class="px-2 py-0.5 text-xs font-medium rounded-lg"
                :class="
                  selected.customized
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{
                  selected.customized
                    ? t('TEKOMI_SETTINGS.PROMPTS.CUSTOMIZED')
                    : t('TEKOMI_SETTINGS.PROMPTS.DEFAULT')
                }}
              </span>
            </div>
            <p class="mt-1 text-xs text-n-slate-11">
              {{ selected.description }} · {{ groupLabel }}
            </p>
          </div>

          <button
            type="button"
            class="px-3 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-12"
            @click="showDiff = !showDiff"
          >
            {{
              showDiff
                ? t('TEKOMI_SETTINGS.PROMPTS.DIFF.HIDE')
                : t('TEKOMI_SETTINGS.PROMPTS.DIFF.SHOW')
            }}
          </button>
        </div>

        <PromptDiff
          v-if="showDiff"
          :default-body="selected.default_body"
          :account-body="draft"
        />
        <PromptEditor v-else v-model="draft" />

        <p class="text-xs text-n-slate-10">
          {{ t('TEKOMI_SETTINGS.PROMPTS.LIQUID_HINT') }}
        </p>

        <div
          class="flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-n-weak"
        >
          <span v-if="isDirty" class="text-xs font-medium text-n-amber-11">
            {{ t('TEKOMI_SETTINGS.PROMPTS.UNSAVED') }}
          </span>
          <span v-else class="text-xs text-n-slate-10">
            {{ t('TEKOMI_SETTINGS.PROMPTS.SAVED') }}
          </span>

          <div class="flex flex-wrap gap-2">
            <button
              v-if="selected.customized"
              type="button"
              class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="uiFlags.isSaving"
              @click="restorePrompt"
            >
              {{ t('TEKOMI_SETTINGS.PROMPTS.RESTORE') }}
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="uiFlags.isSaving || !isDirty"
              @click="savePrompt"
            >
              {{ t('TEKOMI_SETTINGS.PROMPTS.SAVE') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </SettingsShell>
</template>
