class Api::V1::Accounts::Tekomi::DealAssistantMessagesController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :check_authorization
  before_action :set_assistant

  def create
    service = ::Tekomi::Deals::AssistantService.new(
      @assistant,
      user_id: Current.user.id,
      deal_id: permitted_params[:deal_id],
      pipeline_id: permitted_params[:pipeline_id],
      previous_history: previous_history
    )
    @response = service.generate_response(permitted_params.require(:message))
    render json: { response: @response['response'].presence || @response['content'] }
  rescue CustomExceptions::Llm::FeatureNotConfigured => e
    render_could_not_create_error(e.message)
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('crm_deals_ai')
  end

  def check_authorization
    authorize(Deal, :index?)
  end

  def set_assistant
    @assistant = Current.account.tekomi_assistants.first
    render_could_not_create_error(I18n.t('crm_deals.ai.assistant_missing')) if @assistant.blank?
  end

  def previous_history
    permitted_params[:previous_history].to_a.map { |entry| { role: entry[:role], content: entry[:content] } }
  end

  def permitted_params
    params.permit(:message, :deal_id, :pipeline_id, previous_history: [:role, :content])
  end
end
