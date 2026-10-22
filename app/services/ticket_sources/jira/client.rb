# Thin Jira Cloud REST v3 client (Basic auth with an Atlassian account email + API token).
class TicketSources::Jira::Client
  REDIRECT_CODES = [301, 302, 303, 307, 308].freeze
  JSON_HEADERS = { accept: :json, content_type: :json }.freeze

  pattr_initialize [:site!, :email!, :api_token!]

  def base_url
    @base_url ||= "https://#{site.to_s.sub(%r{\Ahttps?://}, '').split('/').first}"
  end

  def get(path, params = {})
    request(:get, path, headers: JSON_HEADERS.merge(params: params))
  end

  def post(path, body)
    request(:post, path, payload: body.to_json, headers: JSON_HEADERS)
  end

  def put(path, body)
    request(:put, path, payload: body.to_json, headers: JSON_HEADERS)
  end

  def post_file(path, filename, io)
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, File.basename(filename))
      File.binwrite(file_path, io.read)
      File.open(file_path, 'rb') do |file|
        request(:post, path, payload: { multipart: true, file: file }, headers: { accept: :json, 'X-Atlassian-Token': 'no-check' })
      end
    end
  end

  # Attachment content answers with a redirect to a pre-signed media URL that must be fetched without credentials.
  def download(url)
    execute(:get, url).body
  rescue RestClient::ExceptionWithResponse => e
    raise map_error(e) unless REDIRECT_CODES.include?(e.http_code)

    RestClient.get(e.response.headers[:location]).body
  end

  private

  def request(method, path, **options)
    body = execute(method, "#{base_url}#{path}", **options).body
    body.present? ? JSON.parse(body) : {}
  rescue RestClient::ExceptionWithResponse => e
    raise map_error(e)
  rescue RestClient::Exceptions::Timeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise CustomExceptions::TicketSource::TransientError, e.message
  end

  def execute(method, url, **options)
    RestClient::Request.execute(method: method, url: url, user: email, password: api_token, timeout: 30, max_redirects: 0, **options)
  end

  def map_error(error)
    case error.http_code
    when 401, 403 then CustomExceptions::TicketSource::AuthError.new("Jira rejected the credentials (#{error.http_code})")
    when 429 then CustomExceptions::TicketSource::RateLimited.new(retry_after: error.response.headers[:retry_after]&.to_i)
    when 500.. then CustomExceptions::TicketSource::TransientError.new("Jira error #{error.http_code}")
    else CustomExceptions::TicketSource::ApiError.new("Jira error #{error.http_code}: #{error.response.body.to_s.truncate(500)}")
    end
  end
end
