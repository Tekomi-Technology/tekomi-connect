class Api::V1::Accounts::Pipelines::StagesController < Api::V1::Accounts::BaseController
  include CrmFeatureConcern

  before_action :fetch_pipeline
  before_action :fetch_stage, only: [:update, :destroy]

  def create
    @stage = @pipeline.stages.create!(stage_params)
    apply_stage_sla
  end

  def update
    @stage.update!(stage_params)
    apply_stage_sla
  end

  def destroy
    PipelineStage.transaction do
      move_records_to_target_stage if params[:move_to_stage_id].present?
      @stage.destroy!
    end
    head :ok
  rescue ActiveRecord::DeleteRestrictionError
    render_could_not_create_error(I18n.t(@pipeline.pipeline_type_ticket? ? 'crm_tickets.stage_has_tickets' : 'crm_deals.stage_has_deals'))
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

  def move_records_to_target_stage
    target_stage = @pipeline.stages.where.not(id: @stage.id).find(params[:move_to_stage_id])
    # Tickets go through the model so each one closes its stage event and starts the target stage's clock.
    return @stage.tickets.find_each { |ticket| ticket.update!(stage: target_stage) } if @pipeline.pipeline_type_ticket?

    @stage.deals.update_all(stage_id: target_stage.id, closed_at: target_stage.closed? ? Time.current : nil)
  end

  # A blank threshold removes the SLA, which lets a stage such as the final one run untimed.
  def apply_stage_sla
    return unless params[:stage].key?(:sla)

    sla_attributes = params.require(:stage).require(:sla).permit(:threshold_minutes, :warning_threshold_percent)
    return @stage.ticket_stage_sla&.destroy! if sla_attributes[:threshold_minutes].blank?

    sla = @stage.ticket_stage_sla || @stage.build_ticket_stage_sla
    sla.update!(sla_attributes)
  end

  def stage_params
    permitted = params.require(:stage).permit(:name, :color, :stage_type, auto_advance_fields: [])
    # Rails turns an empty array in the request body into nil, so clearing the list would
    # otherwise be dropped from the permitted params and silently keep the old value.
    permitted[:auto_advance_fields] ||= [] if params[:stage].key?(:auto_advance_fields)
    permitted
  end
end
