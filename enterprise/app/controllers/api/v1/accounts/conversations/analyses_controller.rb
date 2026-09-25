class Api::V1::Accounts::Conversations::AnalysesController < Api::V1::Accounts::Conversations::BaseController
  def show
    @analysis = @conversation.conversation_analysis
  end

  def create
    result = Tekomi::Llm::ConversationAnalysisService.new(account: Current.account, conversation_display_id: @conversation.display_id).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    @analysis = ConversationAnalysis.record!(conversation: @conversation, analyzed_by: Current.user, result: result[:message])
    render :show
  end

  def care_suggestion
    @analysis = @conversation.conversation_analysis || raise(ActiveRecord::RecordNotFound)
    result = Tekomi::Llm::CareSuggestionService.new(account: Current.account, analysis: @analysis).perform
    return render_could_not_create_error(result[:error]) if result[:error].present?

    @analysis.update!(care: result[:message])
    render :show
  end
end
