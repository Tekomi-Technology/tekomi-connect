require 'base64'
require 'openssl'

module Phone
  class IceServerBuilder
    def initialize(channel:, user:, current_time: Time.current)
      @channel = channel
      @user = user
      @current_time = current_time
    end

    def call
      channel.ice_servers.map do |configuration|
        urls = Array(configuration['urls'] || configuration[:urls])
        next { urls: urls } unless urls.any? { |url| url.start_with?('turn:', 'turns:') }

        username = "#{expires_at}:#{user.id}"
        {
          urls: urls,
          username: username,
          credential: Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', channel.turn_shared_secret, username))
        }
      end
    end

    private

    attr_reader :channel, :user, :current_time

    def expires_at
      (current_time + channel.turn_credential_ttl.seconds).to_i
    end
  end
end
