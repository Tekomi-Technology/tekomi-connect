class Tekomi::Llm::DealSuggestionSchema < RubyLLM::Schema
  SUGGESTIONS_DESCRIPTION = 'Deals worth creating, one per conversation. Leave the array empty when no conversation shows buying intent.'.freeze
  CONVERSATION_DESCRIPTION = 'The conversation id this suggestion comes from. Must match one of the ids given in the input.'.freeze
  NAME_DESCRIPTION = 'Short deal name a salesperson would recognise, mentioning the product or service discussed.'.freeze
  VALUE_DESCRIPTION = 'Estimated deal value in Vietnamese Dong, as a whole number. Use 0 when the conversation gives no amount.'.freeze
  CLOSE_DATE_DESCRIPTION = 'Expected close date in YYYY-MM-DD format, or an empty string when the conversation gives no timeline.'.freeze
  REASON_DESCRIPTION = 'One sentence quoting what in the conversation shows buying intent, in the language of the conversation.'.freeze
  CONFIDENCE_DESCRIPTION = 'How clear the buying intent is: high, medium or low.'.freeze

  array :suggestions, description: SUGGESTIONS_DESCRIPTION, max_items: 10 do
    object do
      integer :conversation_id, description: CONVERSATION_DESCRIPTION
      string :name, description: NAME_DESCRIPTION, max_length: 120
      integer :value, description: VALUE_DESCRIPTION
      string :expected_close_date, description: CLOSE_DATE_DESCRIPTION, max_length: 10
      string :reason, description: REASON_DESCRIPTION, max_length: 200
      string :confidence, description: CONFIDENCE_DESCRIPTION, enum: %w[high medium low]
    end
  end
end
