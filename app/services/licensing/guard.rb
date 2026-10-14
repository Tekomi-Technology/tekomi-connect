# Single entry point that answers "may this account do X?" for the license layer.
#
# Accounts without a license are unrestricted (backwards compatible). A license with
# `enforce: false` runs in shadow mode: violations are logged but never raised, so
# real usage can be observed before limits are switched on.
class Licensing::Guard
  SEND_ACTIONS = %i[send_message start_call].freeze

  def initialize(account)
    @account = account
    @license = account&.account_license
  end

  def licensed?
    @license.present?
  end

  def check!(action, **opts)
    return true unless licensed?

    error = violation_for(action, **opts)
    return true if error.nil?

    if @license.enforce?
      raise error
    else
      Rails.logger.warn("[licensing:shadow] account=#{@account.id} action=#{action} would_block=#{error.code} data=#{opts}")
      true
    end
  end

  def allowed?(action, **opts)
    check!(action, **opts)
    true
  rescue CustomExceptions::License::Base
    false
  end

  # Record metered usage once the action actually happened.
  def consume!(metric, amount = 1)
    return unless licensed?

    Licensing::Usage.record!(@account, metric, amount)
  end

  private

  def violation_for(action, **opts)
    state = @license.current_state
    return CustomExceptions::License::Suspended.new({}) if state == 'suspended'
    return CustomExceptions::License::Restricted.new({}) if state == 'restricted' && SEND_ACTIONS.include?(action)

    case action
    when :send_message then quota_violation('messages')
    when :start_call then quota_violation('calls') || quota_violation('call_minutes')
    when :create_inbox then inbox_violation(opts[:channel_type])
    end
  end

  def quota_violation(metric)
    limit = @license.quota(metric)
    return nil if limit.nil? || @license.overage_policy == 'allow'

    used = Licensing::Usage.used(@account, metric)
    return nil if used < limit

    CustomExceptions::License::QuotaExceeded.new(metric: metric, limit: limit, used: used)
  end

  def inbox_violation(channel_type)
    return CustomExceptions::License::Restricted.new({}) if @license.restricted?

    key = Licensing::Guard.channel_key(channel_type)
    limit = @license.inbox_channel_limit(key)
    return nil if limit.nil?

    count = @account.inboxes.where(channel_type: channel_type).count
    return nil if count < limit

    CustomExceptions::License::FeatureNotIncluded.new(channel: key, limit: limit, used: count)
  end

  def self.channel_key(channel_type)
    channel_type.to_s.demodulize.underscore
  end
end
