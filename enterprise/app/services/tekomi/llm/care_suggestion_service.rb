class Tekomi::Llm::CareSuggestionService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::CareSuggestionSchema

  pattr_initialize [:account!, :analysis!]

  def perform
    make_api_call(feature: 'care_suggestion', messages: messages, schema: RESPONSE_SCHEMA)
  end

  private

  def messages
    [
      { role: 'system', content: Tekomi::PromptRenderer.render('care_suggestion', language: account.locale_english_name) },
      { role: 'user', content: analysis_text }
    ]
  end

  def analysis_text
    JSON.pretty_generate(
      customer_information: analysis.customer,
      customer_insights: analysis.insight,
      conversation_state: analysis.conversation_state,
      service_quality: {
        served_by: analysis.served_by,
        criteria: analysis.quality.transform_values { |criterion| criterion.slice('score', 'reason') }
      }
    )
  end

  def event_name
    'care_suggestion'
  end
end
