class Tekomi::Llm::ConversationAnalysisService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::ConversationAnalysisSchema

  def perform
    make_api_call(feature: 'conversation_analysis', messages: messages, schema: RESPONSE_SCHEMA)
  end

  private

  def messages
    [
      { role: 'system', content: Tekomi::PromptRenderer.render('conversation_analysis', language: account.locale_english_name) },
      { role: 'user', content: conversation.to_llm_text(include_contact_details: false, token_limit: TOKEN_LIMIT) }
    ]
  end

  def event_name
    'conversation_analysis'
  end
end
