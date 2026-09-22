class Tickets::FilterService < FilterService
  ATTRIBUTE_MODEL = 'ticket_attribute'.freeze
  CURRENT_USER_VALUE = 'me'.freeze

  def initialize(account, user, params)
    @account = account
    super(params, user)
  end

  def perform
    return base_relation if @params[:payload].blank?

    validate_query_operator
    query_builder(@filters['tickets'])
  end

  # Enum attributes arrive as their names (for example "breached") but are stored as
  # integers, and shared views reference the viewer as "me" since they hold no user id.
  def filter_values(query_hash)
    attribute_key = query_hash['attribute_key']
    values = query_hash['values']
    enum_values = Ticket.defined_enums[attribute_key]

    return values.map { |value| enum_values.fetch(value.to_s, value) } if enum_values
    return values.map { |value| value == CURRENT_USER_VALUE ? @user.id : value } if attribute_key == 'assignee_id'

    values.map { |value| value.is_a?(String) ? value.downcase : value }
  end

  def base_relation
    @account.tickets
  end

  def filter_config
    {
      entity: 'Ticket',
      table_name: 'tickets'
    }
  end

  def assignee_presence_filter(table_name, query_hash)
    operator = query_hash[:filter_operator] == 'is_present' ? 'IS NOT NULL' : 'IS NULL'
    "#{table_name}.assignee_id #{operator} #{query_hash[:query_operator]}"
  end
end
