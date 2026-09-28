class ConversationAnalyses::CareSuggestionJob < ApplicationJob
  queue_as :default

  def perform(analysis)
    state = ConversationAnalyses::JobState.new(analysis.conversation, :care)
    result = Tekomi::Llm::CareSuggestionService.new(account: analysis.account, analysis: analysis).perform
    return state.fail!(result[:error]) if result[:error].present?

    analysis.update!(care: result[:message])
    state.finish!
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: analysis.account).capture_exception
    state.fail!
  end
end
