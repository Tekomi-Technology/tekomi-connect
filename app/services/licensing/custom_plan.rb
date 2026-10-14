# Applies hand-edited limits from the Super Admin form to an account's license.
# A blank limit means "unlimited". Features are left untouched (use the account's feature toggles).
class Licensing::CustomPlan
  CHANNEL_KEYS = %w[web_widget email facebook_page instagram whatsapp sms twilio_sms telegram line api tiktok zalo_oa zalo_personal phone].freeze
  COUNT_KEYS = %w[agents inboxes messages calls call_minutes].freeze

  class InvalidInput < StandardError; end

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def perform
    license = @account.account_license || @account.build_account_license(plan_key: 'custom', starts_at: Time.current)
    license.assign_attributes(
      trial: ActiveModel::Type::Boolean.new.cast(@params[:trial]) || false,
      grace_days: @params[:grace_days].presence&.to_i || license.grace_days,
      overage_policy: @params[:overage_policy].presence || license.overage_policy,
      expires_at: parse_expiry,
      quotas: build_quotas
    )
    license.save!
    license
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    raise InvalidInput, e.message
  end

  private

  def parse_expiry
    value = @params[:expires_on].presence
    return nil if value.blank?

    Time.zone.parse(value).end_of_day
  end

  def build_quotas
    quotas = COUNT_KEYS.each_with_object({}) do |key, hash|
      value = parse_limit(@params[key])
      hash[key] = value unless value.nil?
    end
    channels = (@params[:channels] || {}).to_h.slice(*CHANNEL_KEYS).transform_values { |v| parse_limit(v) }.compact
    quotas['inboxes_by_channel'] = channels if channels.present?
    quotas
  end

  def parse_limit(raw)
    return nil if raw.blank?

    Integer(raw.to_s, 10).tap { |n| raise ArgumentError, "limit must not be negative: #{raw}" if n.negative? }
  end
end
