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
    Tekomi::PromptRenderer.render('deal_next_step')
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
