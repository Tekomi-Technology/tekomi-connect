class TicketSources::BaseJob < ApplicationJob
  MAX_ATTEMPTS = 8

  queue_as :medium

  retry_on MutexApplicationJob::LockAcquisitionError, wait: 5.seconds, attempts: 20
  retry_on CustomExceptions::TicketSource::TransientError, wait: :polynomially_longer, attempts: MAX_ATTEMPTS

  rescue_from(CustomExceptions::TicketSource::RateLimited) do |error|
    raise error if executions >= MAX_ATTEMPTS

    retry_job(wait: (error.retry_after || 30).seconds)
  end

  # Bad credentials will not fix themselves on retry; surface the error on the connection instead.
  rescue_from(CustomExceptions::TicketSource::AuthError) { |error| @connection&.record_error(error) }
end
