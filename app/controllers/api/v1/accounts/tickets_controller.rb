class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  include CrmTicketsFeatureConcern

  RESULTS_PER_PAGE = 25
  MAX_RESULTS_PER_PAGE = 100
  SORTABLE_FIELDS = %w[title sla_status position created_at updated_at].freeze
  DATE_RANGE_FIELDS = %w[created_at].freeze

  before_action :check_authorization
  before_action :fetch_ticket, only: [:show, :update, :destroy, :move]

  def filter
    tickets = scope_tickets(::Tickets::FilterService.new(Current.account, Current.user, params.permit!).perform)
    @count = tickets.count
    @stage_stats = stage_stats(tickets)
    @tickets = sort_tickets(tickets).includes(*ticket_preloads).page(params[:page]).per(per_page)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue,
         ArgumentError => e
    render_could_not_create_error(e.message)
  end

  def show; end

  def create
    @ticket = Current.account.tickets.create!(ticket_params.merge(params.require(:ticket).permit(:stage_id)))
  end

  def update
    @ticket.update!(ticket_params)
  end

  def move
    stage = PipelineStage.joins(:pipeline).where(pipelines: { account_id: Current.account.id }).find(params.require(:stage_id))
    after_ticket = stage.tickets.find(params[:after_id]) if params[:after_id].present?
    @ticket = ::Tickets::MoveService.new(ticket: @ticket, stage: stage, after_ticket: after_ticket).perform
  end

  def destroy
    @ticket.destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:id])
  end

  def ticket_preloads
    [:contact, :assignee, :stage_events]
  end

  def ticket_params
    params.require(:ticket).permit(:title, :description, :contact_id, :assignee_id, :created_by, custom_attributes: {})
  end

  def scope_tickets(tickets)
    tickets = tickets.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    tickets = tickets.where(stage_id: params[:stage_id]) if params[:stage_id].present?
    return tickets if params[:date_field].blank?

    raise ArgumentError, "Invalid date field: #{params[:date_field]}" unless DATE_RANGE_FIELDS.include?(params[:date_field])

    date_range = Date.iso8601(params.require(:date_from)).beginning_of_day..Date.iso8601(params.require(:date_to)).end_of_day
    tickets.where(params[:date_field] => date_range)
  end

  def sort_tickets(tickets)
    orders = Array(params[:sorts]).map do |sort|
      raise ArgumentError, I18n.t('crm_tickets.invalid_sort') unless SORTABLE_FIELDS.include?(sort[:field])

      column = Ticket.arel_table[sort[:field]]
      sort[:direction] == 'desc' ? column.desc.nulls_last : column.asc.nulls_last
    end
    tickets.order(*orders, :position, :id)
  end

  def stage_stats(tickets)
    tickets.group(:stage_id).count.map { |stage_id, count| { stage_id: stage_id, count: count } }
  end

  def per_page
    params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_RESULTS_PER_PAGE) : RESULTS_PER_PAGE
  end
end
