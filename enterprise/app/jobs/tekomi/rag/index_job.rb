class Tekomi::Rag::IndexJob < ApplicationJob
  queue_as :low

  RECORD_TYPES = {
    'assistant_response' => 'Tekomi::AssistantResponse',
    'faq_suggestion' => 'Tekomi::FaqSuggestion',
    'article_embedding' => 'ArticleEmbedding'
  }.freeze

  def perform(record_type:, record_id:)
    record = record_class(record_type).find_by(id: record_id)
    return unless record

    account = account_for(record)
    Tekomi::Rag::Client.new(account: account).index(
      record_type: record_type,
      record_id: record.id,
      text: text_for(record),
      payload: payload_for(record)
    )
  end

  private

  def record_class(record_type)
    RECORD_TYPES.fetch(record_type).constantize
  end

  def account_for(record)
    record.respond_to?(:account) ? record.account : record.article.account
  end

  def text_for(record)
    case record
    when Tekomi::AssistantResponse, Tekomi::FaqSuggestion
      "#{record.question}: #{record.answer}"
    when ArticleEmbedding
      record.term
    else
      raise ArgumentError, "Unsupported RAG record: #{record.class.name}"
    end
  end

  def payload_for(record)
    payload = { 'account_id' => account_for(record).id }
    case record
    when Tekomi::AssistantResponse
      payload.merge('assistant_id' => record.assistant_id, 'status' => record.status, 'question' => record.question,
                    'answer' => record.answer)
    when Tekomi::FaqSuggestion
      payload.merge('assistant_id' => record.assistant_id, 'status' => record.status, 'language' => record.language,
                    'question' => record.question, 'answer' => record.answer)
    when ArticleEmbedding
      article = record.article
      payload.merge('article_id' => article.id, 'status' => article.status.to_s, 'language' => article.category&.locale,
                    'category_slug' => article.category&.slug, 'author_id' => article.author_id)
    end
  end
end
