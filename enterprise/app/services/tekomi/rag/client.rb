class Tekomi::Rag::Client
  class Error < StandardError; end

  SERVICE_URL = ENV.fetch('RAG_SERVICE_URL', 'http://rag:8080').delete_suffix('/').freeze

  def initialize(account:)
    @account = account
  end

  def index(record_type:, record_id:, text:, payload: {})
    post('/v1/index', {
      account_id: @account.id,
      record_type: record_type,
      record_id: record_id,
      text: text,
      payload: payload,
      openrouter_api_key: openrouter_api_key
    })
  end

  def index_batch(documents:)
    post('/v1/index/batch', { documents: documents.map { |document| document.merge(openrouter_api_key: openrouter_api_key) } })
  end

  def search(query:, record_type: nil, filters: {}, limit: 5)
    post('/v1/search', {
      account_id: @account.id,
      query: query,
      record_type: record_type,
      filters: filters,
      limit: limit,
      openrouter_api_key: openrouter_api_key
    }.compact)
  end

  def delete(record_type:, record_id:)
    post('/v1/delete', { account_id: @account.id, record_type: record_type, record_id: record_id })
  end

  private

  def openrouter_api_key
    @openrouter_api_key ||= @account.account_llm_providers.find_by!(provider_type: 'openrouter').api_key
  rescue ActiveRecord::RecordNotFound => e
    alert_error = CustomExceptions::Llm::TenantProviderNotConfigured.new(feature: 'rag', provider: 'openrouter')
    Llm::AlertRecorder.record(account: @account, error: alert_error, feature: 'rag', provider: 'openrouter')
    raise
  end

  def post(path, body)
    response = HTTParty.post(
      "#{SERVICE_URL}#{path}",
      headers: headers,
      body: body.to_json,
      timeout: ENV.fetch('RAG_SERVICE_TIMEOUT_SECONDS', 90).to_i
    )
    return response.parsed_response if response.success?

    detail = response.parsed_response.is_a?(Hash) ? response.parsed_response['detail'] : nil
    error = Error.new("RAG service #{path} failed (HTTP #{response.code}): #{detail || response.body.to_s.truncate(500)}")
    Llm::AlertRecorder.record(
      account: @account,
      error: error,
      feature: 'rag',
      provider: 'openrouter',
      status_code: response.code,
      metadata: { path: path }
    )
    raise error
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    error = Error.new("RAG service #{path} unavailable: #{e.message}")
    Llm::AlertRecorder.record(
      account: @account,
      error: error,
      feature: 'rag',
      provider: 'openrouter',
      metadata: { path: path }
    )
    raise error
  end

  def headers
    token = ENV['RAG_SERVICE_TOKEN'].presence
    { 'Content-Type' => 'application/json' }.tap do |result|
      result['X-Rag-Service-Token'] = token if token
    end
  end
end
