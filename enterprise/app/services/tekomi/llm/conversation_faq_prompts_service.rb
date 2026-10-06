class Tekomi::Llm::ConversationFaqPromptsService
  class << self
    def generator(language = 'english', account: nil)
      Tekomi::PromptRenderer.render('conversation_faq', { language: language }, account: account)
    end

    def same_faq(account: nil)
      Tekomi::PromptRenderer.render('conversation_faq_matching', {}, account: account)
    end
  end
end
