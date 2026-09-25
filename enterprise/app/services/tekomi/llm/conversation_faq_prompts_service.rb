class Tekomi::Llm::ConversationFaqPromptsService
  class << self
    def generator(language = 'english')
      Tekomi::PromptRenderer.render('conversation_faq', language: language)
    end

    def same_faq
      Tekomi::PromptRenderer.render('conversation_faq_matching')
    end
  end
end
