# frozen_string_literal: true

module CustomExceptions::License
  class Base < CustomExceptions::Base
    def code
      raise NotImplementedError
    end

    def to_hash
      { message: message, code: code }.merge(@data.slice(:metric, :limit, :used).compact)
    end

    def http_status
      :payment_required
    end
  end

  class Restricted < Base
    def code
      'license_restricted'
    end

    def message
      I18n.t('errors.license.restricted', default: 'This account\'s license has expired. The account is read-only until it is renewed.')
    end
  end

  class Suspended < Base
    def code
      'license_suspended'
    end

    def message
      I18n.t('errors.license.suspended', default: 'This account has been suspended. Please contact support.')
    end
  end

  class QuotaExceeded < Base
    def code
      'license_quota_exceeded'
    end

    def http_status
      :too_many_requests
    end

    def message
      I18n.t('errors.license.quota_exceeded', metric: @data[:metric],
                                              default: "The #{@data[:metric]} quota for this account has been reached.")
    end
  end

  class FeatureNotIncluded < Base
    def code
      'license_channel_limit'
    end

    def message
      I18n.t('errors.license.channel_limit', channel: @data[:channel],
                                             default: "The license does not allow more #{@data[:channel]} inboxes.")
    end
  end
end
