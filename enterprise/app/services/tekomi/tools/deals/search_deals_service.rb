class Tekomi::Tools::Deals::SearchDealsService < Tekomi::Tools::BaseTool
  RESULT_LIMIT = 50

  def self.name
    'search_deals'
  end

  description 'Search deals (sales opportunities) in the CRM pipelines of this account'
  param :pipeline_name, type: :string, desc: 'Filter deals by pipeline name (partial match)'
  param :stage_name, type: :string, desc: 'Filter deals by stage name (partial match), for example New, Proposal, Customer'
  param :stage_type, type: :string, desc: 'Filter by stage type: open, won or lost'
  param :assignee_name, type: :string, desc: 'Filter deals by the name of the assigned agent (partial match)'
  param :contact_name, type: :string, desc: 'Filter deals by the name of the related contact (partial match)'
  param :min_value, type: :integer, desc: 'Only return deals with a value greater than or equal to this amount in VND'
  param :max_value, type: :integer, desc: 'Only return deals with a value lower than or equal to this amount in VND'
  param :expected_close_from, type: :string, desc: 'Only return deals with expected close date on or after this date (YYYY-MM-DD)'
  param :expected_close_to, type: :string, desc: 'Only return deals with expected close date on or before this date (YYYY-MM-DD)'

  def execute(pipeline_name: nil, stage_name: nil, stage_type: nil, assignee_name: nil, contact_name: nil,
              min_value: nil, max_value: nil, expected_close_from: nil, expected_close_to: nil)
    deals = base_relation
    deals = filter_by_pipeline(deals, pipeline_name)
    deals = filter_by_stage(deals, stage_name, stage_type)
    deals = filter_by_people(deals, assignee_name, contact_name)
    deals = filter_by_value(deals, min_value, max_value)
    deals = filter_by_expected_close_date(deals, expected_close_from, expected_close_to)

    return 'No deals found' unless deals.exists?

    deals.limit(RESULT_LIMIT).map(&:to_llm_text).join("\n---\n")
  end

  def active?
    user_has_permission('contact_manage')
  end

  private

  def base_relation
    Deal.where(account_id: @assistant.account_id).includes(:pipeline, :stage, :assignee, :contact)
  end

  def filter_by_pipeline(deals, pipeline_name)
    return deals if pipeline_name.blank?

    deals.joins(:pipeline).where('LOWER(pipelines.name) ILIKE ?', "%#{pipeline_name.downcase}%")
  end

  def filter_by_stage(deals, stage_name, stage_type)
    deals = deals.joins(:stage).where('LOWER(pipeline_stages.name) ILIKE ?', "%#{stage_name.downcase}%") if stage_name.present?
    return deals if stage_type.blank?

    deals.joins(:stage).where(pipeline_stages: { stage_type: PipelineStage.stage_types[stage_type] })
  end

  def filter_by_people(deals, assignee_name, contact_name)
    deals = deals.joins(:assignee).where('LOWER(users.name) ILIKE ?', "%#{assignee_name.downcase}%") if assignee_name.present?
    return deals if contact_name.blank?

    deals.joins(:contact).where('LOWER(contacts.name) ILIKE ?', "%#{contact_name.downcase}%")
  end

  def filter_by_value(deals, min_value, max_value)
    deals = deals.where(value: min_value..) if min_value.present?
    deals = deals.where(value: ..max_value) if max_value.present?
    deals
  end

  def filter_by_expected_close_date(deals, expected_close_from, expected_close_to)
    from = parse_date(expected_close_from)
    to = parse_date(expected_close_to)
    deals = deals.where(expected_close_date: from..) if from.present?
    deals = deals.where(expected_close_date: ..to) if to.present?
    deals
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end
end
