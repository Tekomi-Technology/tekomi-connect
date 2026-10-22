module CustomExceptions::TicketSource
  class ApiError < StandardError; end

  class AuthError < ApiError; end

  # The source understood the request and refused it (validation, workflow rules, missing resource, ...).
  class RejectedError < ApiError; end

  class TransientError < ApiError; end

  class RateLimited < TransientError
    attr_reader :retry_after

    def initialize(message = 'Rate limited', retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end
end
