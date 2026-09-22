class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  include CrmFeatureConcern

  before_action :check_authorization
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = Current.account.pipelines.order(:position, :id).includes(stages: :ticket_stage_sla)
    @pipelines = @pipelines.where(pipeline_type: params[:pipeline_type]) if params[:pipeline_type].present?
  end

  def show; end

  def create
    @pipeline = Current.account.pipelines.create!(pipeline_params.merge(params.require(:pipeline).permit(:pipeline_type)))
  end

  def update
    @pipeline.update!(pipeline_params)
  end

  def destroy
    @pipeline.destroy!
    head :ok
  end

  def reorder
    params.require(:ids).each_with_index do |id, index|
      Current.account.pipelines.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name)
  end
end
