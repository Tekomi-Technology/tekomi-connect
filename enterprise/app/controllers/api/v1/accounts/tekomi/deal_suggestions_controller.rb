class Api::V1::Accounts::Tekomi::DealSuggestionsController < Api::V1::Accounts::BaseController
  CONVERSATION_LIMIT = 10
  DEFAULT_DAYS = 14

  before_action :ensure_feature_enabled
  before_action :check_authorization

  def create
    conversations = candidate_conversations
    return render json: { payload: [] } if conversations.blank?

    result = ::Tekomi::Llm::DealSuggestionService.new(account: Current.account, conversations: conversations).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    render json: { payload: build_payload(result[:message], conversations) }
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_deals_ai')
  end

  def check_authorization
    authorize(Deal, :create?)
  end

  def candidate_conversations
    conversations = Current.account.conversations
                           .includes(:contact, :inbox)
                           .where.not(id: DealConversation.select(:conversation_id))
                           .where(last_activity_at: since..)
    ::Conversations::PermissionFilterService.new(conversations, Current.user, Current.account)
                                            .perform
                                            .order(last_activity_at: :desc)
                                            .limit(CONVERSATION_LIMIT)
  end

  def since
    days = permitted_params[:days].presence&.to_i || DEFAULT_DAYS
    days.days.ago
  end

  def build_payload(message, conversations)
    conversations_by_display_id = conversations.index_by(&:display_id)

    Array(message['suggestions']).filter_map do |suggestion|
      conversation = conversations_by_display_id[suggestion['conversation_id']]
      next if conversation.blank?

      suggestion_payload(suggestion, conversation)
    end
  end

  def suggestion_payload(suggestion, conversation)
    {
      conversation_id: conversation.display_id,
      contact: conversation.contact&.slice(:id, :name),
      name: suggestion['name'],
      value: suggestion['value'].to_i.positive? ? suggestion['value'].to_i : nil,
      expected_close_date: suggestion['expected_close_date'].presence,
      reason: suggestion['reason'],
      confidence: suggestion['confidence']
    }
  end

  def permitted_params
    params.permit(:days)
  end
end
