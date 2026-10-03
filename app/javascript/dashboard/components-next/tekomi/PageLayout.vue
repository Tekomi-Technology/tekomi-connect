<script setup>
import { ref, computed } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Button from 'dashboard/components-next/button/Button.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Policy from 'dashboard/components/policy.vue';
import AssistantSwitcher from 'dashboard/components-next/tekomi/pageComponents/switcher/AssistantSwitcher.vue';
import CreateAssistantDialog from 'dashboard/components-next/tekomi/pageComponents/assistant/CreateAssistantDialog.vue';

const props = defineProps({
  currentPage: {
    type: Number,
    default: 1,
  },
  totalCount: {
    type: Number,
    default: 100,
  },
  itemsPerPage: {
    type: Number,
    default: 25,
  },
  headerTitle: {
    type: String,
    default: '',
  },
  backUrl: {
    type: [String, Object],
    default: '',
  },
  buttonPolicy: {
    type: Array,
    default: () => [],
  },
  buttonLabel: {
    type: String,
    default: '',
  },
  featureFlag: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  showKnowMore: {
    type: Boolean,
    default: true,
  },
  isEmpty: {
    type: Boolean,
    default: false,
  },
  showPaginationFooter: {
    type: Boolean,
    default: true,
  },
  showAssistantSwitcher: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['click', 'close', 'update:currentPage']);

const { t } = useI18n();

const route = useRoute();
const { shouldShowPaywall } = usePolicy();

const showAssistantSwitcherDropdown = ref(false);
const createAssistantDialogRef = ref(null);

const assistants = useMapGetter('tekomiAssistants/getRecords');
const uiFlags = useMapGetter('tekomiAssistants/getUIFlags');

const currentAssistantId = computed(() => route.params.assistantId);
const isFetchingAssistants = computed(() => uiFlags.value?.fetchingList);

const activeAssistantName = computed(() => {
  return (
    assistants.value?.find(
      assistant => assistant.id === Number(currentAssistantId.value)
    )?.name || t('TEKOMI.ASSISTANT_SWITCHER.NEW_ASSISTANT')
  );
});

const showPaywall = computed(() => {
  return shouldShowPaywall(props.featureFlag);
});

const handleButtonClick = () => {
  emit('click');
};

const handlePageChange = event => {
  emit('update:currentPage', event);
};

const toggleAssistantSwitcher = () => {
  showAssistantSwitcherDropdown.value = !showAssistantSwitcherDropdown.value;
};

const handleCreateAssistant = () => {
  showAssistantSwitcherDropdown.value = false;
  createAssistantDialogRef.value.dialogRef.open();
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <div class="relative z-10 px-6 pt-6">
      <header
        class="flex flex-col gap-4 p-6 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
      >
        <div
          class="flex flex-col items-start justify-between w-full gap-4 lg:flex-row lg:items-center"
        >
          <div class="flex items-center min-w-0 gap-3">
            <BackButton v-if="backUrl" :back-url="backUrl" />
            <div
              v-if="showAssistantSwitcher && !showPaywall"
              class="flex items-center gap-2"
            >
              <div class="flex items-center gap-2">
                <span
                  v-if="!isFetchingAssistants"
                  class="text-2xl font-semibold tracking-tight truncate text-n-slate-12"
                >
                  {{ activeAssistantName }}
                </span>
                <div class="relative group">
                  <OnClickOutside
                    @trigger="showAssistantSwitcherDropdown = false"
                  >
                    <Button
                      icon="i-lucide-chevron-down"
                      :variant="
                        showAssistantSwitcherDropdown ? 'faded' : 'ghost'
                      "
                      color="slate"
                      size="xs"
                      :disabled="isFetchingAssistants"
                      :is-loading="isFetchingAssistants"
                      class="rounded-md group-hover:bg-n-slate-3 hover:bg-n-slate-3 [&>span]:size-4"
                      @click="toggleAssistantSwitcher"
                    />

                    <AssistantSwitcher
                      v-if="showAssistantSwitcherDropdown"
                      class="absolute ltr:left-0 rtl:right-0 top-9"
                      @close="showAssistantSwitcherDropdown = false"
                      @create-assistant="handleCreateAssistant"
                    />
                  </OnClickOutside>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <div
                v-if="showAssistantSwitcher && !showPaywall && headerTitle"
                class="w-0.5 h-4 rounded-2xl bg-n-weak"
              />
              <h1
                v-if="headerTitle"
                class="text-2xl font-semibold tracking-tight text-n-slate-12"
              >
                {{ headerTitle }}
              </h1>
              <div
                v-if="!isEmpty && showKnowMore"
                class="flex items-center gap-2"
              >
                <div class="w-0.5 h-4 rounded-2xl bg-n-weak" />
                <slot name="knowMore" />
              </div>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <slot name="headerActions" />
            <slot name="search" />
            <div
              v-if="!showPaywall && buttonLabel"
              v-on-clickaway="() => emit('close')"
              class="relative group/tekomi-button"
            >
              <Policy :permissions="buttonPolicy">
                <Button
                  :label="buttonLabel"
                  icon="i-lucide-plus"
                  size="sm"
                  class="group-hover/tekomi-button:brightness-110"
                  @click="handleButtonClick"
                />
              </Policy>
              <slot name="action" />
            </div>
          </div>
        </div>
        <!-- Empty wrappers (e.g. a bulk bar with nothing selected) must not add a gap. -->
        <div
          v-if="$slots.subHeader"
          class="flex flex-col gap-2 empty:hidden [&>*:empty]:hidden"
        >
          <slot name="subHeader" />
        </div>
        <slot v-if="!showPaywall" name="controls" />
      </header>
    </div>
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full h-full py-5">
        <div
          v-if="isFetching"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else-if="showPaywall">
          <slot name="paywall" />
        </div>
        <div v-else-if="isEmpty">
          <slot name="emptyState" />
        </div>
        <slot v-else name="body" />
        <slot />
      </div>
    </main>
    <footer v-if="showPaginationFooter" class="sticky bottom-0 z-10">
      <PaginationFooter
        :current-page="currentPage"
        :total-items="totalCount"
        :items-per-page="itemsPerPage"
        @update:current-page="handlePageChange"
      />
    </footer>
    <CreateAssistantDialog ref="createAssistantDialogRef" type="create" />
  </section>
</template>
