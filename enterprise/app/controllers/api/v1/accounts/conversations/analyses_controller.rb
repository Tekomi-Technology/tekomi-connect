class Api::V1::Accounts::Conversations::AnalysesController < Api::V1::Accounts::Conversations::BaseController
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
end
