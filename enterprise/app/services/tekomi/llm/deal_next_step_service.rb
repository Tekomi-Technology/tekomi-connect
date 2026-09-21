class Tekomi::Llm::DealNextStepService < Tekomi::BaseTaskService
  RESPONSE_SCHEMA = Tekomi::Llm::DealNextStepSchema
  TRANSCRIPT_MESSAGE_LIMIT = 40

  pattr_initialize [:account!, :deal!, :conversations!]

  def perform
    make_api_call(feature: 'deal_next_step', messages: messages, schema: RESPONSE_SCHEMA)
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
      You advise a salesperson on what to do next with one deal (a sales opportunity).

      Base your advice only on the deal data, the conversations with the customer and the change history given to you.
      Suggest moving the deal to another stage only when the conversation clearly shows it, for example the customer
      accepted a quote, asked to sign, or said they are not buying. Otherwise keep the deal where it is.
      Money amounts are in Vietnamese Dong. Write in the language used in the conversations with the customer.
    PROMPT
  end

  def user_prompt
    [
      "Today is #{Time.zone.today}.",
      deal.to_llm_text,
      "Stages available in this pipeline:\n#{stages_text}",
      "Conversations:\n#{conversations_text}"
    ].join("\n\n")
  end

  def stages_text
    deal.pipeline.stages.map { |stage| "- id #{stage.id}: #{stage.name} (#{stage.stage_type})" }.join("\n")
  end

  def conversations_text
    return 'No conversations linked to this deal' if conversations.blank?

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
    'deal_next_step'
  end
end
