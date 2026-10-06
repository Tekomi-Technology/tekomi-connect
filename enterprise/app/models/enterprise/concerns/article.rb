module Enterprise::Concerns::Article
  extend ActiveSupport::Concern

  included do
    after_save :add_article_embedding, if: -> { saved_change_to_title? || saved_change_to_description? || saved_change_to_content? }

    def self.add_article_embedding_association
      has_many :article_embeddings, dependent: :destroy_async
    end

    add_article_embedding_association

    def self.vector_search(params)
      limit = params.key?(:limit) ? params[:limit] : 5
      filters = {
        'category_slug' => params[:category_slug],
        'language' => params[:locale],
        'author_id' => params[:author_id]&.to_i,
        'status' => params[:status].presence&.to_s
      }.compact
      hits = Tekomi::Rag::SearchService.new(account: Account.find(params[:account_id])).article_embeddings(
        query: params['query'],
        filters: filters,
        limit: limit || 50
      )
      article_ids = hits.filter_map { |hit| hit['payload']['article_id']&.to_i }.uniq

      where(id: article_ids).in_order_of(:id, article_ids)
    end
  end

  def add_article_embedding
    return unless account.feature_enabled?('help_center_embedding_search')

    Portal::ArticleIndexingJob.perform_later(self)
  end

  def generate_and_save_article_seach_terms
    terms = generate_article_search_terms
    article_embeddings.destroy_all
    terms.each { |term| article_embeddings.create!(term: term) }
  end

  def article_to_search_terms_prompt
    Tekomi::PromptRenderer.render('article_search_terms')
  end

  def generate_article_search_terms
    route = Llm::FeatureRouter.resolve(feature: 'article_search_terms', account: account)
    response = route[:context].chat(model: route[:model], provider: route[:provider], assume_model_exists: true)
                      .with_params(**route[:params], response_format: { type: 'json_object' })
                      .with_instructions(article_to_search_terms_prompt)
                      .ask("title: #{title} \n description: #{description} \n content: #{content}")
    JSON.parse(response.content)['search_terms']
  end
end
