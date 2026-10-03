class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  include CrmDealsFeatureConcern

  RESULTS_PER_PAGE = 25
  MAX_RESULTS_PER_PAGE = 100
  SORTABLE_FIELDS = %w[name value expected_close_date closed_at position created_at updated_at].freeze
  DATE_RANGE_FIELDS = %w[expected_close_date closed_at created_at].freeze

  before_action :check_authorization
  before_action :fetch_deal, only: [:show, :update, :destroy, :move]

  def filter
    deals = scope_deals(::Deals::FilterService.new(Current.account, Current.user, params.permit!).perform)
    @count = deals.count
    @stage_stats = stage_stats(deals)
    @deals = sort_deals(deals).includes(*deal_preloads).page(params[:page]).per(per_page)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue,
         ArgumentError => e
    render_could_not_create_error(e.message)
  end

  def show; end

  def create
    @deal = Current.account.deals.create!(deal_params.merge(params.require(:deal).permit(:stage_id)))
  end

  def update
    @deal.update!(deal_params)
  end

  def move
    stage = PipelineStage.joins(:pipeline).where(pipelines: { account_id: Current.account.id }).find(params.require(:stage_id))
    after_deal = stage.deals.find(params[:after_id]) if params[:after_id].present?
    @deal = ::Deals::MoveService.new(deal: @deal, stage: stage, after_deal: after_deal).perform
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:id])
  end

  def deal_preloads
    [:contact, :assignee]
  end

  def deal_params
    params.require(:deal).permit(:name, :value, :contact_id, :assignee_id, :expected_close_date, custom_attributes: {})
  end

  def scope_deals(deals)
    deals = deals.where(pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(stage_id: params[:stage_id]) if params[:stage_id].present?
    return deals if params[:date_field].blank?

    raise ArgumentError, "Invalid date field: #{params[:date_field]}" unless DATE_RANGE_FIELDS.include?(params[:date_field])
    return deals.where(params[:date_field] => nil) if params[:date_missing].present?

    date_range = Date.iso8601(params.require(:date_from)).beginning_of_day..Date.iso8601(params.require(:date_to)).end_of_day
    deals.where(params[:date_field] => date_range)
  end

  def sort_deals(deals)
    orders = Array(params[:sorts]).map do |sort|
      raise ArgumentError, I18n.t('crm_deals.invalid_sort') unless SORTABLE_FIELDS.include?(sort[:field])

      column = Deal.arel_table[sort[:field]]
      sort[:direction] == 'desc' ? column.desc.nulls_last : column.asc.nulls_last
    end
    deals.order(*orders, :position, :id)
  end

  def stage_stats(deals)
    deals.group(:stage_id).pluck(
      :stage_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(value), 0)'), Arel.sql('AVG(value)'), Arel.sql('MIN(value)'), Arel.sql('MAX(value)')
    ).map do |stage_id, count, sum, avg, min, max|
      { stage_id: stage_id, count: count, sum: sum, avg: avg&.round, min: min, max: max }
    end
  end

  def per_page
    params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_RESULTS_PER_PAGE) : RESULTS_PER_PAGE
  end
end

Api::V1::Accounts::DealsController.prepend_mod_with('Api::V1::Accounts::DealsController')
