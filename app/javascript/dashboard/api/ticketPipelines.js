/* global axios */
import ApiClient from './ApiClient';

// Pipelines are shared with deals on the server, so every call here pins the
// ticket type to keep the two boards apart.
class TicketPipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  get() {
    return axios.get(this.url, { params: { pipeline_type: 'ticket' } });
  }

  create({ name }) {
    return axios.post(this.url, {
      pipeline: { name, pipeline_type: 'ticket' },
    });
  }

  reorder(ids) {
    return axios.patch(`${this.url}/reorder`, { ids });
  }

  createStage(pipelineId, stage) {
    return axios.post(`${this.url}/${pipelineId}/stages`, { stage });
  }

  updateStage(pipelineId, stageId, stage) {
    return axios.patch(`${this.url}/${pipelineId}/stages/${stageId}`, {
      stage,
    });
  }

  deleteStage(pipelineId, stageId, moveToStageId) {
    return axios.delete(`${this.url}/${pipelineId}/stages/${stageId}`, {
      params: { move_to_stage_id: moveToStageId || undefined },
    });
  }

  reorderStages(pipelineId, ids) {
    return axios.patch(`${this.url}/${pipelineId}/stages/reorder`, { ids });
  }
}

export default new TicketPipelinesAPI();
