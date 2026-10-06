class Tekomi::Tools::SearchReplyDocumentationService < RubyLLM::Tool
  prepend Tekomi::Tools::Instrumentation

  description 'Search and retrieve documentation/FAQs from knowledge base'

  param :query, desc: 'Search Query', required: true

  def initialize(account:, assistant: nil)
    @account = account
    @assistant = assistant
    super()
  end

  def name
    'search_documentation'
  end

  def execute(query:)
    Rails.logger.info { "#{self.class.name}: #{query}" }

    translated_query = Tekomi::Llm::TranslateQueryService
                       .new(account: @account)
                       .translate(query, target_language: @account.locale_english_name)

    responses = search_responses(translated_query).map(&:record)
    return 'No FAQs found for the given query' if responses.empty?

    responses.map { |response| format_response(response) }.join
  end

  private

  def search_responses(query)
    assistant = @assistant || @account.tekomi_assistants.first
    return [] unless assistant

    Tekomi::Rag::SearchService.new(account: @account).assistant_responses(
      assistant: assistant,
      query: query
    )
  end

  def format_response(response)
    result = "\nQuestion: #{response.question}\nAnswer: #{response.answer}\n"
    result += "Source: #{response.documentable.external_link}\n" if response.documentable.present? && response.documentable.try(:external_link)
    result
  end
end
