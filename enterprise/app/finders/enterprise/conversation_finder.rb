module Enterprise::ConversationFinder
  def perform
    super.tap { |result| result[:count][:company_counts] = @company_counts if @company_counts }
  end

  def perform_meta_only
    super.tap { |result| result[:count][:company_counts] = @company_counts if @company_counts }
  end

  def conversations_base_query
    return super unless current_account.feature_enabled?('sla')

    super.includes(:applied_sla, :sla_events, inbox: :working_hours)
  end

  private

  def set_up
    super
    return unless current_account.feature_enabled?('companies')

    @company_counts = @conversations.unscope(:order).joins(:contact).where.not(contacts: { company_id: nil })
                                    .group('contacts.company_id').count
    filter_by_company
  end

  def filter_by_company
    return if params[:company_id].blank?

    @conversations = @conversations.where(contact_id: current_account.contacts.where(company_id: params[:company_id]).select(:id))
  end
end
