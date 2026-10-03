class Deals::FilterService < FilterService
  ATTRIBUTE_MODEL = 'deal_attribute'.freeze

  def initialize(account, user, params)
    @account = account
    super(params, user)
  end

  def perform
    return base_relation if @params[:payload].blank?

    validate_query_operator
    query_builder(@filters['deals'])
  end

  def filter_values(query_hash)
    query_hash['values'].map { |value| value.is_a?(String) ? value.downcase : value }
  end

  def base_relation
    @account.deals
  end

  def filter_config
    {
      entity: 'Deal',
      table_name: 'deals'
    }
  end

  def assignee_presence_filter(table_name, query_hash)
    operator = query_hash[:filter_operator] == 'is_present' ? 'IS NOT NULL' : 'IS NULL'
    "#{table_name}.assignee_id #{operator} #{query_hash[:query_operator]}"
  end
end
