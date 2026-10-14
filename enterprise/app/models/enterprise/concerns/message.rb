module Enterprise::Concerns::Message
  extend ActiveSupport::Concern

  # Call logs are written by the telephony layer, not sent by an agent, so they are never metered.
  LICENSE_UNMETERED_CONTENT_TYPES = %w[voice_call phone_call].freeze

  included do
    has_one :call, dependent: :nullify
    has_many :message_reports, class_name: 'Tekomi::MessageReport', dependent: :destroy_async

    validate :licensing_allows_send, on: :create
    after_create_commit :licensing_record_send
  end

  private

  def licensing_metered?
    outgoing? && !private? && LICENSE_UNMETERED_CONTENT_TYPES.exclude?(content_type.to_s)
  end

  def licensing_allows_send
    return unless licensing_metered? && account.present?

    Licensing::Guard.new(account).check!(:send_message)
  rescue CustomExceptions::License::Base => e
    errors.add(:base, e.message)
  end

  def licensing_record_send
    return unless licensing_metered?

    Licensing::Guard.new(account).consume!(:messages)
  rescue StandardError => e
    Rails.logger.error("[licensing] failed to record message for account #{account_id}: #{e.message}")
  end
end
