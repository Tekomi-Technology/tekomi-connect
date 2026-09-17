class Api::V1::Accounts::Pipelines::StagesController < Api::V1::Accounts::BaseController
  include CrmDealsFeatureConcern

  before_action :fetch_pipeline
  before_action :fetch_stage, only: [:update, :destroy]

  def create
    @stage = @pipeline.stages.create!(stage_params)
  end

  def update
    @stage.update!(stage_params)
  end

  def destroy
    PipelineStage.transaction do
      move_deals_to_target_stage if params[:move_to_stage_id].present?
      @stage.destroy!
    end
    head :ok
  rescue ActiveRecord::DeleteRestrictionError
    render_could_not_create_error(I18n.t('crm_deals.stage_has_deals'))
  end

  def reorder
    params.require(:ids).each_with_index do |id, index|
      @pipeline.stages.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
    authorize @pipeline, :update?
  end

  def fetch_stage
    @stage = @pipeline.stages.find(params[:id])
  end

  def move_deals_to_target_stage
    target_stage = @pipeline.stages.where.not(id: @stage.id).find(params[:move_to_stage_id])
    @stage.deals.update_all(stage_id: target_stage.id, closed_at: target_stage.closed? ? Time.current : nil)
  end

  def stage_params
    params.require(:stage).permit(:name, :color, :stage_type)
  end
end
