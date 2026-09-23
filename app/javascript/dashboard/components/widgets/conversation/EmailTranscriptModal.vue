<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import TicketsAPI from 'dashboard/api/tickets';
import { useTicketsStore } from 'dashboard/stores/tickets';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    currentChat: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['cancel', 'update:show'],
  setup() {
    return {
      v$: useVuelidate(),
      ticketsStore: useTicketsStore(),
      ticketPipelinesStore: useTicketPipelinesStore(),
    };
  },
  data() {
    return {
      email: '',
      note: '',
      selectedType: '',
      isSubmitting: false,
      ticketTitle: '',
      ticketDescription: '',
      ticketStageId: '',
      ticketAssigneeId: '',
    };
  },
  validations: {
    email: {
      required,
      email,
      minLength: minLength(4),
    },
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      agents: 'agents/getAgents',
    }),
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
    sentToOtherEmailAddress() {
      return this.selectedType === 'other_email_address';
    },
    sentToExternalSystem() {
      return this.selectedType === 'other_system';
    },
    sentAsInternalTicket() {
      return this.selectedType === 'internal_ticket';
    },
    hasCrmTickets() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CRM_TICKETS
      );
    },
    ticketStages() {
      return this.ticketPipelinesStore.records.flatMap(pipeline =>
        pipeline.stages.map(stage => ({
          ...stage,
          name:
            this.ticketPipelinesStore.records.length > 1
              ? `${pipeline.name} · ${stage.name}`
              : stage.name,
        }))
      );
    },
    isCrmMatched() {
      const senderId = this.currentChat.meta?.sender?.id;
      if (!senderId) return false;
      const contact = this.$store.getters['contacts/getContact'](senderId);
      return !!contact?.additional_attributes?.external?.perfex_contact_id;
    },
    isFormValid() {
      if (this.sentAsInternalTicket) {
        return !!this.ticketTitle.trim() && !!this.ticketStageId;
      }
      if (this.selectedType) {
        if (this.sentToOtherEmailAddress) {
          return !!this.email && !this.v$.email.$error;
        }
        return true;
      }
      return false;
    },
    selectedEmailAddress() {
      const { meta } = this.currentChat;
      switch (this.selectedType) {
        case 'contact':
          return meta.sender.email;
        case 'assignee':
          return meta.assignee.email;
        case 'other_email_address':
          return this.email;
        default:
          return '';
      }
    },
  },
  watch: {
    selectedType(value) {
      // Default to the first stage as soon as the internal ticket option is picked,
      // so the submit button is enabled without an extra click.
      if (value === 'internal_ticket' && !this.ticketStageId) {
        this.ticketStageId = this.ticketStages[0]?.id || '';
      }
    },
  },
  mounted() {
    if (this.hasCrmTickets && !this.ticketPipelinesStore.records.length) {
      this.ticketPipelinesStore.fetch();
    }
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    async createInternalTicket() {
      const ticket = await this.ticketsStore.create({
        title: this.ticketTitle.trim(),
        description: this.ticketDescription.trim() || null,
        stage_id: this.ticketStageId,
        assignee_id: this.ticketAssigneeId || null,
        contact_id: this.currentChat.meta?.sender?.id || null,
      });
      await TicketsAPI.linkConversation(ticket.id, this.currentChat.id);
      emitter.emit(BUS_EVENTS.TICKET_LINKED_TO_CONVERSATION, this.currentChat.id);
      useAlert(this.$t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.SUCCESS'));
    },
    async onSubmit() {
      this.isSubmitting = false;
      try {
        if (this.sentAsInternalTicket) {
          await this.createInternalTicket();
        } else if (this.sentToExternalSystem) {
          await this.$store.dispatch('sendConversationToExternalSystem', {
            conversationId: this.currentChat.id,
            note: this.note,
          });
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EXTERNAL_SYSTEM_SUCCESS'));
        } else {
          await this.$store.dispatch('sendEmailTranscript', {
            email: this.selectedEmailAddress,
            conversationId: this.currentChat.id,
          });
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'));
        }
        this.onCancel();
      } catch (error) {
        const status = error?.response?.status;
        if (status === 402) {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_PAYMENT_REQUIRED'));
        } else if (this.sentAsInternalTicket) {
          useAlert(this.$t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.ERROR'));
        } else if (this.sentToExternalSystem) {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EXTERNAL_SYSTEM_ERROR'));
        } else {
          useAlert(this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'));
        }
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onCancel">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('EMAIL_TRANSCRIPT.TITLE')"
        :header-content="$t('EMAIL_TRANSCRIPT.DESC')"
      />
      <form class="w-full" @submit.prevent="onSubmit">
        <div class="w-full">
          <div
            v-if="currentChat.meta.sender && currentChat.meta.sender.email"
            class="flex items-center gap-2"
          >
            <input
              id="contact"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="contact"
            />
            <label for="contact">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_CONTACT')
            }}</label>
          </div>
          <div
            v-if="
              currentChat.meta.assignee &&
              currentChat.meta.assignee_type !== 'AgentBot'
            "
            class="flex items-center gap-2"
          >
            <input
              id="assignee"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="assignee"
            />
            <label for="assignee">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_AGENT')
            }}</label>
          </div>
          <div class="flex items-center gap-2">
            <input
              id="other_email_address"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="other_email_address"
            />
            <label for="other_email_address">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_OTHER_EMAIL_ADDRESS')
            }}</label>
          </div>
          <div class="flex items-center gap-2">
            <input
              id="other_system"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="other_system"
              :disabled="!isCrmMatched"
            />
            <label for="other_system">{{
              $t('EMAIL_TRANSCRIPT.FORM.SEND_TO_EXTERNAL_SYSTEM')
            }}</label>
            <span v-if="!isCrmMatched" class="text-xs text-n-slate-11">
              {{ $t('EMAIL_TRANSCRIPT.FORM.EXTERNAL_SYSTEM_DISABLED_HINT') }}
            </span>
          </div>
          <div v-if="hasCrmTickets" class="flex items-center gap-2">
            <input
              id="internal_ticket"
              v-model="selectedType"
              type="radio"
              name="selectedType"
              value="internal_ticket"
            />
            <label for="internal_ticket">{{
              $t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.LABEL')
            }}</label>
          </div>
          <div v-if="sentToExternalSystem" class="w-full mt-1">
            <textarea
              v-model="note"
              rows="3"
              class="w-full"
              :placeholder="$t('EMAIL_TRANSCRIPT.FORM.NOTE.PLACEHOLDER')"
            />
          </div>
          <div v-if="sentToOtherEmailAddress" class="w-[50%] mt-1">
            <label :class="{ error: v$.email.$error }">
              <input
                v-model="email"
                type="text"
                :placeholder="$t('EMAIL_TRANSCRIPT.FORM.EMAIL.PLACEHOLDER')"
                @input="v$.email.$touch"
              />
              <span v-if="v$.email.$error" class="message">
                {{ $t('EMAIL_TRANSCRIPT.FORM.EMAIL.ERROR') }}
              </span>
            </label>
          </div>
          <div v-if="sentAsInternalTicket" class="flex flex-col w-full gap-2 mt-1">
            <input
              v-model="ticketTitle"
              type="text"
              :placeholder="$t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.TITLE_PLACEHOLDER')"
            />
            <textarea
              v-model="ticketDescription"
              rows="2"
              class="w-full"
              :placeholder="$t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.DESCRIPTION_PLACEHOLDER')"
            />
            <div class="flex gap-2">
              <select v-model="ticketStageId" class="w-1/2">
                <option v-for="stage in ticketStages" :key="stage.id" :value="stage.id">
                  {{ stage.name }}
                </option>
              </select>
              <select v-model="ticketAssigneeId" class="w-1/2">
                <option value="">
                  {{ $t('EMAIL_TRANSCRIPT.FORM.INTERNAL_TICKET.UNASSIGNED') }}
                </option>
                <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                  {{ agent.name }}
                </option>
              </select>
            </div>
          </div>
        </div>
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('EMAIL_TRANSCRIPT.CANCEL')"
            @click.prevent="onCancel"
          />
          <NextButton
            type="submit"
            :label="$t('EMAIL_TRANSCRIPT.SUBMIT')"
            :disabled="!isFormValid"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
