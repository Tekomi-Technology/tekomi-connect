class Api::V1::Accounts::Tekomi::DealSummariesController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :set_deal

  def create
    result = ::Tekomi::Llm::DealSummaryService.new(
      account: Current.account,
      deal: @deal,
      conversations: accessible_conversations
    ).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    render json: { payload: { summary: result[:message]['summary'], highlights: Array(result[:message]['highlights']) } }
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_deals_ai')
  end

  def set_deal
    @deal = Current.account.deals.find(params.require(:deal_id))
    authorize(@deal, :show?)
  end

  def accessible_conversations
    ::Conversations::PermissionFilterService.new(
      @deal.conversations.includes(:inbox, :contact),
      Current.user,
      Current.account
    ).perform
  end
end
