class Crm::Perfex::Api::BaseClient
  include HTTParty

  class ApiError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def initialize(base_url:, api_key:)
    @base_url = base_url
    @api_key = api_key
  end

  def get(path, params = {})
    full_url = URI.join(@base_url, path).to_s
    response = self.class.get(full_url, query: params, headers: headers)
    handle_response(response)
  rescue HTTParty::Error, Timeout::Error, SocketError, SystemCallError, EOFError => e
    error_message = "Perfex CRM API connection error: #{e.message}"
    Rails.logger.error error_message
    raise ApiError.new(error_message, nil, nil)
  end

  def post(path, body = {})
    full_url = URI.join(@base_url, path).to_s
    response = self.class.post(full_url, body: body.to_json, headers: headers)
    handle_response(response)
  rescue HTTParty::Error, Timeout::Error, SocketError, SystemCallError, EOFError => e
    error_message = "Perfex CRM API connection error: #{e.message}"
    Rails.logger.error error_message
    raise ApiError.new(error_message, nil, nil)
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }
  end

  def handle_response(response)
    case response.code
    when 200..299
      handle_success(response)
    else
      error_message = "Perfex CRM API error: #{response.code} - #{response.body}"
      Rails.logger.error error_message
      raise ApiError.new(error_message, response.code, response)
    end
  end

  def handle_success(response)
    parse_response(response)
  rescue JSON::ParserError, TypeError => e
    error_message = "Failed to parse Perfex CRM API response: #{e.message}"
    raise ApiError.new(error_message, response.code, response)
  end

  def parse_response(response)
    body = response.parsed_response

    if body.is_a?(Hash) && body['success'] == false
      error_message = body['message'] || 'Unknown Perfex CRM API error'
      raise ApiError.new(error_message, response.code, response)
    else
      body
    end
  end
end
