class Tekomi::Tools::Deals::DealStatsService < Tekomi::Tools::BaseTool
  GROUP_BY_OPTIONS = %w[stage assignee pipeline].freeze

  def self.name
    'deal_stats'
  end

  description 'Get aggregated deal numbers: how many deals and the total value, grouped by stage, assignee or pipeline'
  param :group_by, type: :string, desc: 'Group the results by: stage, assignee or pipeline. Defaults to stage'
  param :pipeline_name, type: :string, desc: 'Only count deals in the pipeline with this name (partial match)'
  param :open_only, type: :string, desc: 'Set to "true" to only count deals that are not won or lost yet'

  def execute(group_by: 'stage', pipeline_name: nil, open_only: nil)
    return "Invalid group_by. Use one of: #{GROUP_BY_OPTIONS.join(', ')}" unless GROUP_BY_OPTIONS.include?(group_by.to_s)

    deals = base_relation(pipeline_name, open_only)
    rows = deals.group(group_column(group_by)).pluck(group_column(group_by), Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(deals.value), 0)'))
    return 'No deals found' if rows.empty?

    rows.map { |label, count, total| "#{label || 'Unassigned'}: #{count} deals, total #{ActiveSupport::NumberHelper.number_to_delimited(total)} VND" }
        .join("\n")
  end

  def active?
    user_has_permission('contact_manage')
  end

  private

  def base_relation(pipeline_name, open_only)
    deals = Deal.where(account_id: @assistant.account_id).joins(:pipeline, :stage).left_joins(:assignee)
    deals = deals.where('LOWER(pipelines.name) ILIKE ?', "%#{pipeline_name.downcase}%") if pipeline_name.present?
    deals = deals.where(pipeline_stages: { stage_type: PipelineStage.stage_types[:open] }) if open_only.to_s == 'true'
    deals
  end

  def group_column(group_by)
    {
      'stage' => 'pipeline_stages.name',
      'assignee' => 'users.name',
      'pipeline' => 'pipelines.name'
    }[group_by.to_s]
  end
end
