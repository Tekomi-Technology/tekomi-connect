class Tekomi::Rag::SearchService
  Hit = Data.define(:record, :score, :payload)

  RECORD_TYPES = {
    assistant_response: 'assistant_response',
    faq_suggestion: 'faq_suggestion',
    article_embedding: 'article_embedding'
  }.freeze

  def initialize(account:)
    @account = account
    @client = Tekomi::Rag::Client.new(account: account)
  end

  def assistant_responses(assistant:, query:, statuses: ['approved'], limit: 5)
    hits = search(record_type: RECORD_TYPES[:assistant_response], query: query,
                  filters: { 'assistant_id' => assistant.id, 'status' => statuses }, limit: limit)
    records = assistant.responses.where(id: hits.map { |hit| hit['record_id'] }).includes(:documentable).index_by(&:id)
    build_hits(hits, records)
  end

  def faq_suggestions(assistant:, query:, status:, language:, limit: 5)
    hits = search(record_type: RECORD_TYPES[:faq_suggestion], query: query,
                  filters: { 'assistant_id' => assistant.id, 'status' => status, 'language' => language }, limit: limit)
    records = assistant.faq_suggestions.where(id: hits.map { |hit| hit['record_id'] }).index_by(&:id)
    build_hits(hits, records)
  end

  def article_embeddings(query:, filters: {}, limit: 20)
    search(record_type: RECORD_TYPES[:article_embedding], query: query, filters: filters, limit: limit)
  end

  private

  def search(**arguments)
    @client.search(**arguments).fetch('hits', [])
  end

  def build_hits(hits, records)
    hits.filter_map do |hit|
      record = records[hit['record_id'].to_i]
      Hit.new(record, hit['score'].to_f, hit['payload']) if record
    end
  end
end
