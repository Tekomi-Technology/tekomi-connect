module Enterprise::ConversationFinder
  def perform
    super.tap { |result| result[:count].merge!(@company_meta) if @company_meta }
  end

  def perform_meta_only
    super.tap { |result| result[:count].merge!(@company_meta) if @company_meta }
  end

  def conversations_base_query
    return super unless current_account.feature_enabled?('sla')

    super.includes(:applied_sla, :sla_events, inbox: :working_hours)
  end

  private

  def set_up
    super
    return unless current_account.feature_enabled?('companies')

    @company_meta = company_meta
    filter_by_company
  end

  # One grouped query gives the per-company counts, the companies with a starred
  # contact waiting for a reply, and the count of conversations without a company.
  def company_meta
    rows = @conversations.unscope(:order).joins(:contact).group('contacts.company_id').pluck(
      'contacts.company_id',
      Arel.sql('COUNT(*)'),
      Arel.sql('COUNT(*) FILTER (WHERE contacts.vip AND conversations.waiting_since IS NOT NULL)')
    )
    no_company_rows, company_rows = rows.partition { |company_id, _, _| company_id.nil? }

    {
      company_counts: company_rows.to_h { |company_id, count, _| [company_id, count] },
      company_starred_waiting_ids: company_rows.filter_map { |company_id, _, waiting| company_id if waiting.positive? },
      no_company_count: no_company_rows.dig(0, 1) || 0
    }
  end

  def filter_by_company
    return if params[:company_id].blank?

    company_id = params[:company_id] == 'none' ? nil : params[:company_id]
    @conversations = @conversations.where(contact_id: current_account.contacts.where(company_id: company_id).select(:id))
  end
end
