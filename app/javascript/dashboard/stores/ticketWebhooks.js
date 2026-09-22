import camelcaseKeys from 'camelcase-keys';
import TicketWebhooksAPI from 'dashboard/api/ticketWebhooks';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { defineStore } from 'pinia';

const camelize = data => camelcaseKeys(data, { deep: true });

export const useTicketWebhooksStore = defineStore('ticketWebhooks', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isCreating: false },
  }),

  actions: {
    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const { data } = await TicketWebhooksAPI.get();
        this.records = camelize(data.payload);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    // The token only comes back on this call, so the caller has to show it right away.
    async create({ name, pipelineId }) {
      this.uiFlags.isCreating = true;
      try {
        const { data } = await TicketWebhooksAPI.create({
          ticket_webhook: { name, pipeline_id: pipelineId },
        });
        const record = camelize(data);
        this.records.push(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isCreating = false;
      }
    },

    async delete(id) {
      try {
        await TicketWebhooksAPI.delete(id);
        this.records = this.records.filter(webhook => webhook.id !== id);
      } catch (error) {
        throwErrorMessage(error);
      }
    },
  },
});
