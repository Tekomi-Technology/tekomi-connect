class Tekomi::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  def initialize(account_id: nil)
    @account_id = account_id
    @route = Llm::FeatureRouter.resolve(feature: 'embedding', account: Account.find_by(id: account_id))
  end

  def get_embedding(content)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content)) do
      RubyLLM.embed(
        content, model: @route[:model], provider: @route[:provider], context: @route[:context], assume_model_exists: true
      ).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content)
    {
      span_name: 'llm.tekomi.embedding',
      model: @route[:model],
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end
