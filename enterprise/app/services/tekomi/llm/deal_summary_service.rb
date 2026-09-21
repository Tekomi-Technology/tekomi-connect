class Tekomi::Llm::DealSummaryService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::DealSummarySchema
  TRANSCRIPT_MESSAGE_LIMIT = 40
  ACTIVITY_LIMIT = 20

  pattr_initialize [:account!, :deal!, :conversations!]

  def perform
    make_api_call(feature: 'deal_summary', messages: messages, schema: RESPONSE_SCHEMA)
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
      You summarise a deal (a sales opportunity) for the salesperson who owns it.

      Base the summary only on the deal data, the conversations with the customer and the change history given to you.
      Never invent amounts, dates or commitments. When something is unknown, leave it out instead of guessing.
      Money amounts are in Vietnamese Dong. Write in the language used in the conversations with the customer.
    PROMPT
  end

  def user_prompt
    [deal.to_llm_text, "Change history:\n#{activities_text}", "Conversations:\n#{conversations_text}"].join("\n\n")
  end

  def activities_text
    activities = deal.activities.includes(:actor).limit(ACTIVITY_LIMIT)
    return 'No changes recorded' if activities.empty?

    activities.map do |activity|
      "- #{activity.created_at.to_date}: #{activity.actor&.name || 'System'} #{activity.action} #{activity.metadata.to_json}"
    end.join("\n")
  end

  def conversations_text
    return 'No conversations linked to this deal' if conversations.blank?

    conversations.map { |conversation| conversation_section(conversation) }.join("\n\n")
  end

  def conversation_section(conversation)
    <<~SECTION.strip
      Conversation id: #{conversation.display_id}
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
    'deal_summary'
  end
end
