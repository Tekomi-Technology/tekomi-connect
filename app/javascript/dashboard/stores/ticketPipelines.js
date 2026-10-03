import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import TicketPipelinesAPI from 'dashboard/api/ticketPipelines';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { defineStore } from 'pinia';

const camelize = data => camelcaseKeys(data, { deep: true });

export const useTicketPipelinesStore = defineStore('ticketPipelines', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isSaving: false },
  }),

  getters: {
    getPipeline: state => id =>
      state.records.find(pipeline => pipeline.id === Number(id)),
  },

  actions: {
    async run(request) {
      this.uiFlags.isSaving = true;
      try {
        return await request();
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    replacePipeline(pipeline) {
      const index = this.records.findIndex(record => record.id === pipeline.id);
      if (index === -1) this.records.push(pipeline);
      else this.records[index] = pipeline;
      return pipeline;
    },

    updateStages(pipelineId, updater) {
      const pipeline = this.getPipeline(pipelineId);
      pipeline.stages = updater(pipeline.stages);
    },

    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const { data } = await TicketPipelinesAPI.get();
        this.records = camelize(data.payload);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    create(name) {
      return this.run(async () => {
        const { data } = await TicketPipelinesAPI.create({ name });
        return this.replacePipeline(camelize(data));
      });
    },

    update(id, name) {
      return this.run(async () => {
        const { data } = await TicketPipelinesAPI.update(id, {
          pipeline: { name },
        });
        return this.replacePipeline(camelize(data));
      });
    },

    delete(id) {
      return this.run(async () => {
        await TicketPipelinesAPI.delete(id);
        this.records = this.records.filter(pipeline => pipeline.id !== id);
      });
    },

    reorder(ids) {
      this.records = ids.map(id => this.getPipeline(id));
      return this.run(() => TicketPipelinesAPI.reorder(ids));
    },

    createStage(pipelineId, stage) {
      return this.run(async () => {
        const { data } = await TicketPipelinesAPI.createStage(
          pipelineId,
          snakecaseKeys(stage)
        );
        this.updateStages(pipelineId, stages => [...stages, camelize(data)]);
      });
    },

    updateStage(pipelineId, stageId, changes) {
      return this.run(async () => {
        const { data } = await TicketPipelinesAPI.updateStage(
          pipelineId,
          stageId,
          snakecaseKeys(changes)
        );
        this.updateStages(pipelineId, stages =>
          stages.map(stage => (stage.id === stageId ? camelize(data) : stage))
        );
      });
    },

    deleteStage(pipelineId, stageId, moveToStageId) {
      return this.run(async () => {
        await TicketPipelinesAPI.deleteStage(pipelineId, stageId, moveToStageId);
        this.updateStages(pipelineId, stages =>
          stages.filter(stage => stage.id !== stageId)
        );
      });
    },

    reorderStages(pipelineId, ids) {
      this.updateStages(pipelineId, stages =>
        ids.map(id => stages.find(stage => stage.id === id))
      );
      return this.run(() => TicketPipelinesAPI.reorderStages(pipelineId, ids));
    },
  },
});
