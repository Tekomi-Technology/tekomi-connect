class Tekomi::Llm::DealFieldExtractionService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::DealFieldExtractionSchema
  TRANSCRIPT_MESSAGE_LIMIT = 40

  pattr_initialize [:account!, :deal!, :conversations!, :definitions!]

  def perform
    return { message: { 'fields' => [] } } if definitions.blank? || conversations.blank?

    make_api_call(feature: 'deal_field_extraction', messages: messages, schema: RESPONSE_SCHEMA)
  end

  private

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_prompt }
    ]
  end

  def system_prompt
    <<~PROMPT
      You fill in the custom fields of a deal (a sales opportunity) using what the customer said in the conversations.

      Only propose a value when the conversations state it or clearly imply it. Never guess.
      Skip a field entirely when the conversations say nothing about it.
      Money amounts are in Vietnamese Dong: return digits only, without separators or currency symbols.
    PROMPT
  end

  def user_prompt
    [
      "Today is #{Time.zone.today}.",
      deal.to_llm_text,
      "Fields you can fill:\n#{definitions_text}",
      "Conversations:\n#{conversations_text}"
    ].join("\n\n")
  end

  def definitions_text
    definitions.map { |definition| definition_line(definition) }.join("\n")
  end

  def definition_line(definition)
    line = "- key: #{definition.attribute_key}, name: #{definition.attribute_display_name}, type: #{definition.attribute_display_type}"
    line += ", allowed values: #{definition.attribute_values.join(', ')}" if definition.attribute_values.present?
    line += ", current value: #{deal.custom_attributes[definition.attribute_key]}" if deal.custom_attributes[definition.attribute_key].present?
    line
  end

  def conversations_text
    conversations.map { |conversation| "Conversation id: #{conversation.display_id}\n#{transcript(conversation)}" }.join("\n\n")
  end

  def transcript(conversation)
    lines = conversation.messages
                        .where(message_type: [:incoming, :outgoing], private: false)
                        .reorder(id: :desc)
                        .limit(TRANSCRIPT_MESSAGE_LIMIT)
                        .filter_map { |message| message_line(message) }
    lines.reverse.join("\n").presence || 'No messages'
  end

  def message_line(message)
    content = message.content_for_llm
    return if content.blank?

    "#{message.incoming? ? 'Customer' : 'Agent'}: #{content}"
  end

  def event_name
    'deal_field_extraction'
  end
end
