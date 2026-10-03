class Mailbox::ConversationFinder
  DEFAULT_STRATEGIES = [
    Mailbox::ConversationFinderStrategies::ReceiverUuidStrategy,
    Mailbox::ConversationFinderStrategies::InReplyToStrategy,
    Mailbox::ConversationFinderStrategies::ReferencesStrategy,
    Mailbox::ConversationFinderStrategies::NewConversationStrategy
  ].freeze

  def initialize(mail, strategies: DEFAULT_STRATEGIES)
    @mail = mail
    @strategies = strategies
  end

  def find
    @strategies.each do |strategy_class|
      conversation = strategy_class.new(@mail).find

      next unless conversation
      next if resolved_conversation_requires_new_thread?(conversation)

      strategy_name = strategy_class.name.demodulize.underscore
      Rails.logger.info "Conversation found via #{strategy_name} strategy"
      return conversation
    end

    # Should not reach here if NewConversationStrategy is in the chain
    Rails.logger.error 'No conversation found via any strategy (NewConversationStrategy missing?)'
    nil
  end

  private

  def resolved_conversation_requires_new_thread?(conversation)
    return false if conversation.new_record? || !conversation.resolved?

    !conversation.inbox.lock_to_single_conversation?
  end
end
