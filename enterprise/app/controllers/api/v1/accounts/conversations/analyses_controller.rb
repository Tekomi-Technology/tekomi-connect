class Api::V1::Accounts::Conversations::AnalysesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_conversation_analysis_enabled, only: [:create, :care_suggestion]

  def show
    @analysis = @conversation.conversation_analysis
  end

  def create
    if ConversationAnalyses::JobState.new(@conversation, :analysis).start
      ConversationAnalyses::AnalyzeJob.perform_later(@conversation, Current.user)
    end
    @analysis = @conversation.conversation_analysis
    render :show, status: :accepted
  end

  def care_suggestion
    @analysis = @conversation.conversation_analysis || raise(ActiveRecord::RecordNotFound)
    ConversationAnalyses::CareSuggestionJob.perform_later(@analysis) if ConversationAnalyses::JobState.new(@conversation, :care).start
    render :show, status: :accepted
  end

  private

  def ensure_conversation_analysis_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('conversation_analysis')
  end
end
