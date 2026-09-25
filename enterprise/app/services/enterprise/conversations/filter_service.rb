module Enterprise::Conversations::FilterService
  ANALYSIS_FILTERS = {
    'analysis_interest_level' => {
      'attribute_type' => 'conversation_analysis', 'data_type' => 'text', 'filter_operators' => %w[equal_to not_equal_to]
    },
    'analysis_quality_score' => {
      'attribute_type' => 'conversation_analysis', 'data_type' => 'numeric',
      'filter_operators' => %w[equal_to not_equal_to is_present is_not_present is_greater_than is_less_than]
    }
  }.freeze

  ANALYSIS_COLUMNS = {
    'analysis_interest_level' => "conversation_analyses.insight ->> 'interest_level'",
    'analysis_quality_score' => 'conversation_analyses.quality_score'
  }.freeze

  def initialize(params, user, account)
    super
    @filters['conversations'] = @filters['conversations'].merge(ANALYSIS_FILTERS)
  end

  def build_condition_query_string(current_filter, query_hash, current_index)
    return super unless current_filter&.dig('attribute_type') == 'conversation_analysis'

    filter_operator_value = filter_operation(query_hash, current_index)
    "(SELECT #{ANALYSIS_COLUMNS.fetch(query_hash['attribute_key'])} FROM conversation_analyses " \
      "WHERE conversation_analyses.conversation_id = conversations.id) #{filter_operator_value} #{query_hash[:query_operator]}"
  end
end
