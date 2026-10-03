class ZaloOa::Client
  class Error < StandardError; end

  OAUTH_BASE = 'https://oauth.zaloapp.com/v4/oa'.freeze
  API_BASE = 'https://openapi.zalo.me'.freeze

  class << self
    def permission_url(app_id:, redirect_uri:, state:)
      query = { app_id: app_id, redirect_uri: redirect_uri, state: state }.to_query
      "#{OAUTH_BASE}/permission?#{query}"
    end

    def exchange_code(app_id:, app_secret:, code:)
      request_token(app_secret, app_id: app_id, grant_type: 'authorization_code', code: code)
    end

    def refresh_token(app_id:, app_secret:, refresh_token:)
      request_token(app_secret, app_id: app_id, grant_type: 'refresh_token', refresh_token: refresh_token)
    end

    def fetch_oa_profile(access_token)
      body = get("#{API_BASE}/v2.0/oa/getoa", access_token)
      oa_id = body.dig('data', 'oa_id')
      raise Error, "getoa failed: #{body['error']} #{body['message']}".strip if oa_id.blank?

      { oa_id: oa_id.to_s, name: body.dig('data', 'name').presence }
    end

    def fetch_user_profile(access_token, user_id)
      body = get("#{API_BASE}/v3.0/oa/user/detail", access_token, data: { user_id: user_id }.to_json)
      data = body['data']
      return nil if data.blank? || data['display_name'].blank?

      { name: data['display_name'].to_s, avatar_url: data['avatar'].presence }
    end

    def send_request_user_info(access_token:, user_id:, title:, subtitle:, image_url: nil)
      message = {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'request_user_info',
            elements: [{ title: title, subtitle: subtitle, image_url: image_url }.compact]
          }
        }
      }
      post_message(access_token, user_id, message)
    end

    def list_recent_chats(access_token:, oa_id:, offset:, count:)
      body = get("#{API_BASE}/v2.0/oa/listrecentchat", access_token,
                 data: { offset: offset, count: count }.to_json)
      rows = body['data'].is_a?(Array) ? body['data'] : body.dig('data', 'chats')
      Array(rows).filter_map do |row|
        next unless row.respond_to?(:with_indifferent_access)

        row = row.with_indifferent_access
        from_id = row[:from_id].to_s
        to_id = row[:to_id].to_s
        user_id = from_id.present? && from_id != oa_id.to_s ? from_id : to_id
        user_id.present? ? row.merge(user_id: user_id) : nil
      end
    end

    def conversation_messages(access_token:, user_id:, offset:, count:)
      body = get("#{API_BASE}/v2.0/oa/conversation", access_token,
                 data: { user_id: user_id, offset: offset, count: count }.to_json)
      rows = body['data'].is_a?(Array) ? body['data'] : body.dig('data', 'messages')
      Array(rows).filter_map { |row| row.with_indifferent_access if row.respond_to?(:with_indifferent_access) }
    end

    private

    # The app secret travels in a `secret_key` header, not the form body.
    def request_token(app_secret, fields)
      response = HTTParty.post(
        "#{OAUTH_BASE}/access_token",
        headers: { 'secret_key' => app_secret, 'Content-Type' => 'application/x-www-form-urlencoded' },
        body: URI.encode_www_form(fields)
      )
      body = response.parsed_response
      raise Error, "token request failed: #{body.try(:[], 'error')} #{body.try(:[], 'message')}".strip if body.try(:[], 'access_token').blank?

      {
        access_token: body['access_token'],
        refresh_token: body['refresh_token'],
        expires_in: body.fetch('expires_in', 3600).to_i
      }
    end

    def get(url, access_token, query = {})
      response = HTTParty.get(url, headers: { 'access_token' => access_token }, query: query)
      raise Error, "request to #{url} failed with status #{response.code}" unless response.success?

      body = response.parsed_response
      raise Error, "request to #{url} failed: #{body['error']} #{body['message']}" if body.is_a?(Hash) && body['error'].to_i != 0

      body
    end

    def post_message(access_token, user_id, message)
      response = HTTParty.post(
        "#{API_BASE}/v3.0/oa/message/cs",
        headers: { 'access_token' => access_token, 'Content-Type' => 'application/json' },
        body: { recipient: { user_id: user_id }, message: message }.to_json
      )
      body = response.parsed_response
      unless response.success? && body.is_a?(Hash) && body['error'].to_i.zero?
        raise Error, "request user info failed: #{body.try(:[], 'error')} #{body.try(:[], 'message')}".strip
      end

      body
    end
  end
end
