class Tekomi::Llm::DealSuggestionService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::DealSuggestionSchema
  TRANSCRIPT_MESSAGE_LIMIT = 30

  pattr_initialize [:account!, :conversations!]

  def perform
    return { message: { 'suggestions' => [] } } if conversations.blank?

    make_api_call(feature: 'deal_suggestion', messages: messages, schema: RESPONSE_SCHEMA)
  end

  private

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_prompt }
    ]
  end

  def system_prompt
    Tekomi::PromptRenderer.render('deal_suggestion')
  end

  def user_prompt
    ["Today is #{Time.zone.today}.", *conversations.map { |conversation| conversation_section(conversation) }].join("\n\n")
  end

  def conversation_section(conversation)
    <<~SECTION.strip
      Conversation id: #{conversation.display_id}
      Contact: #{conversation.contact&.name}
      Transcript:
      #{transcript(conversation)}
    SECTION
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
    'deal_suggestion'
  end
end
