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
    raise Error, "RAG service #{path} failed (HTTP #{response.code}): #{detail || response.body.to_s.truncate(500)}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise Error, "RAG service #{path} unavailable: #{e.message}"
  end

  def headers
    token = ENV['RAG_SERVICE_TOKEN'].presence
    { 'Content-Type' => 'application/json' }.tap do |result|
      result['X-Rag-Service-Token'] = token if token
    end
  end
end
