<script>
import { ref } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useTekomi } from 'dashboard/composables/useTekomi';
import { useTrack } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';
import { REPLY_EDITOR_MODES, CHAR_LENGTH_WARNING } from './constants';
import { TEKOMI_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import NextButton from 'dashboard/components-next/button/Button.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

export default {
  name: 'ReplyTopPanel',
  components: {
    NextButton,
    CopilotMenuBar,
  },
  directives: {
    OnClickOutside: vOnClickOutside,
  },
  props: {
    mode: {
      type: String,
      default: REPLY_EDITOR_MODES.REPLY,
    },
    isReplyRestricted: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      default: null,
    },
    isMessageLengthReachingThreshold: {
      type: Boolean,
      default: () => false,
    },
    charactersRemaining: {
      type: Number,
      default: () => 0,
    },
    editorContent: {
      type: String,
      default: undefined,
    },
    hasContent: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['setReplyMode', 'toggleEditorSize', 'executeCopilotAction'],
  setup(props, { emit }) {
    const setReplyMode = mode => {
      emit('setReplyMode', mode);
    };
    const handleReplyClick = () => {
      if (props.isReplyRestricted) return;
      setReplyMode(REPLY_EDITOR_MODES.REPLY);
    };
    const handleNoteClick = () => {
      setReplyMode(REPLY_EDITOR_MODES.NOTE);
    };

    const { tekomiTasksEnabled } = useTekomi();
    const showCopilotMenu = ref(false);
    const copilotToggleRef = ref(null);

    const handleCopilotAction = (actionKey, data) => {
      emit('executeCopilotAction', actionKey, data || props.editorContent);
      showCopilotMenu.value = false;
    };

    const toggleCopilotMenu = () => {
      const isOpening = !showCopilotMenu.value;
      if (isOpening) {
        useTrack(TEKOMI_EVENTS.EDITOR_AI_MENU_OPENED, {
          conversationId: props.conversationId,
          entryPoint: 'top_panel',
        });
      }
      showCopilotMenu.value = isOpening;
    };

    const handleClickOutside = () => {
      showCopilotMenu.value = false;
    };

    const keyboardEvents = {
      'Alt+KeyP': {
        action: () => handleNoteClick(),
        allowOnFocusedInput: false,
      },
      'Alt+KeyL': {
        action: () => handleReplyClick(),
        allowOnFocusedInput: false,
      },
    };
    useKeyboardEvents(keyboardEvents);

    return {
      handleReplyClick,
      handleNoteClick,
      REPLY_EDITOR_MODES,
      tekomiTasksEnabled,
      handleCopilotAction,
      showCopilotMenu,
      copilotToggleRef,
      toggleCopilotMenu,
      handleClickOutside,
    };
  },
  computed: {
    isNoteMode() {
      return this.isReplyRestricted || this.mode === REPLY_EDITOR_MODES.NOTE;
    },
    modeTabs() {
      return [
        {
          key: 'reply',
          label: this.$t('CONVERSATION.REPLYBOX.REPLY'),
          isActive: !this.isNoteMode,
          disabled: this.disabled || this.isReplyRestricted,
          activeClass: 'text-n-brand border-n-brand',
          onClick: this.handleReplyClick,
        },
        {
          key: 'note',
          label: this.$t('CONVERSATION.REPLYBOX.PRIVATE_NOTE'),
          isActive: this.isNoteMode,
          disabled: this.disabled,
          activeClass: 'text-n-amber-11 border-n-amber-9',
          onClick: this.handleNoteClick,
        },
      ];
    },
    charLengthClass() {
      return this.charactersRemaining < 0 ? 'text-n-ruby-9' : 'text-n-slate-11';
    },
    characterLengthWarning() {
      return this.charactersRemaining < 0
        ? `${-this.charactersRemaining} ${CHAR_LENGTH_WARNING.NEGATIVE}`
        : `${this.charactersRemaining} ${CHAR_LENGTH_WARNING.UNDER_50}`;
    },
  },
};
</script>

<template>
  <div
    class="flex justify-between gap-2 h-[3.25rem] items-center ltr:pl-3 ltr:pr-2 rtl:pr-3 rtl:pl-2"
  >
    <div class="flex items-end self-stretch gap-4">
      <button
        v-for="tab in modeTabs"
        :key="tab.key"
        type="button"
        class="h-full px-0.5 text-sm border-b-2 -mb-px transition-colors disabled:cursor-not-allowed disabled:opacity-60"
        :class="
          tab.isActive
            ? `font-semibold ${tab.activeClass}`
            : 'font-medium text-n-slate-11 border-transparent hover:enabled:text-n-slate-12'
        "
        :disabled="tab.disabled"
        @click="tab.onClick"
      >
        {{ tab.label }}
      </button>
    </div>
    <div class="flex items-center mx-4 my-0">
      <div v-if="isMessageLengthReachingThreshold" class="text-xs">
        <span :class="charLengthClass">
          {{ characterLengthWarning }}
        </span>
      </div>
    </div>
    <div v-if="tekomiTasksEnabled" class="flex items-center gap-2">
      <div class="relative">
        <NextButton
          ref="copilotToggleRef"
          ghost
          :disabled="disabled || isEditorDisabled"
          :class="{
            'text-n-violet-9 hover:enabled:!bg-n-violet-3': !showCopilotMenu,
            'text-n-violet-9 bg-n-violet-3': showCopilotMenu,
          }"
          sm
          icon="i-woot-tekomi"
          :label="$t('CONVERSATION.REPLYBOX.AI_SUGGEST')"
          @click="toggleCopilotMenu"
        />
        <CopilotMenuBar
          v-if="showCopilotMenu"
          v-on-click-outside="[
            handleClickOutside,
            { ignore: [copilotToggleRef] },
          ]"
          :has-selection="false"
          :has-content="hasContent"
          :conversation-id="conversationId"
          class="ltr:right-0 rtl:left-0 bottom-full mb-2"
          @execute-copilot-action="handleCopilotAction"
        />
      </div>
      <NextButton
        ghost
        class="text-n-slate-11"
        sm
        icon="i-lucide-maximize-2"
        @click="$emit('toggleEditorSize')"
      />
    </div>
  </div>
</template>
