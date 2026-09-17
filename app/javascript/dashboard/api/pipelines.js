/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
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

export default new PipelinesAPI();
