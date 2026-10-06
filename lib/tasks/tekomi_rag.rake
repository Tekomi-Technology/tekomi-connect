namespace :tekomi do
  namespace :rag do
    desc 'Backfill all FAQ, FAQ suggestion, and help-center embeddings into Qdrant'
    task backfill: :environment do
      records = [
        [Tekomi::AssistantResponse, 'assistant_response'],
        [Tekomi::FaqSuggestion, 'faq_suggestion'],
        [ArticleEmbedding, 'article_embedding']
      ]

      records.each do |model, record_type|
        model.find_each do |record|
          Tekomi::Rag::IndexJob.perform_now(record_type: record_type, record_id: record.id)
        end
      end

      puts 'Tekomi RAG backfill completed.'
    end
  end
end
