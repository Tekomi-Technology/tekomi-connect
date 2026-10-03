class Api::V1::Accounts::Tekomi::DealNextStepsController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :set_deal

  def create
    result = ::Tekomi::Llm::DealNextStepService.new(
      account: Current.account,
      deal: @deal,
      conversations: accessible_conversations
    ).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    render json: { payload: build_payload(result[:message]) }
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

  def build_payload(message)
    {
      next_step: message['next_step'],
      reason: message['reason'],
      suggested_stage: suggested_stage(message['suggested_stage_id']).then { |stage| stage&.slice(:id, :name) }
    }
  end

  def suggested_stage(stage_id)
    return if stage_id.to_i == @deal.stage_id

    @deal.pipeline.stages.find_by(id: stage_id)
  end
end
