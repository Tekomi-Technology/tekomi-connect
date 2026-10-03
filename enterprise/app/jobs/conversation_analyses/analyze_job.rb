class ConversationAnalyses::AnalyzeJob < ApplicationJob
  queue_as :default

  def perform(conversation, user)
    state = ConversationAnalyses::JobState.new(conversation, :analysis)
    result = Tekomi::Llm::ConversationAnalysisService.new(
      account: conversation.account, conversation_display_id: conversation.display_id
    ).perform
    return state.fail!(result[:error]) if result[:error].present?

    ConversationAnalysis.record!(conversation: conversation, analyzed_by: user, result: result[:message])
    state.finish!
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    state.fail!
  end
end
