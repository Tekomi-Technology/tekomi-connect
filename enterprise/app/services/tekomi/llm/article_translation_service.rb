class Tekomi::Llm::ArticleTranslationService < Tekomi::BaseTaskService
  TYPES = %i[title content].freeze

  pattr_initialize [:account!, :text!, :target_language!, :type!]

  def perform
    raise ArgumentError, "Invalid type: #{type}" unless TYPES.include?(type)

    response = make_api_call(feature: 'help_center_article_generation', messages: messages)
    return response if response[:error]

    response.merge(message: response[:message].strip)
  end

  private

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: text }
    ]
  end

  def system_prompt
    type == :title ? title_system_prompt : content_system_prompt
  end

  def event_name
    'article_translation'
  end

  def title_system_prompt
    Tekomi::PromptRenderer.render('article_title_translation', target_language: target_language)
  end

  def content_system_prompt
    Tekomi::PromptRenderer.render('article_content_translation', target_language: target_language)
  end
end
