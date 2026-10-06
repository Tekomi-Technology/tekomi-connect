class Tekomi::Llm::UpdateEmbeddingJob < ApplicationJob
  queue_as :low

  # Kept as a compatibility shim for jobs already persisted in Sidekiq when the
  # vector store was migrated. New callbacks enqueue Tekomi::Rag::IndexJob.
  def perform(record, _content = nil)
    record_type = case record
                  when Tekomi::AssistantResponse then 'assistant_response'
                  when Tekomi::FaqSuggestion then 'faq_suggestion'
                  when ArticleEmbedding then 'article_embedding'
                  else raise ArgumentError, "Unsupported embedding record: #{record.class.name}"
                  end
    Tekomi::Rag::IndexJob.perform_now(record_type: record_type, record_id: record.id)
  end
end
