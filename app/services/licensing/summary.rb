# Serializes an account's license state and usage for the dashboard and Super Admin.
class Licensing::Summary
  def initialize(account)
    @account = account
    @license = account.account_license
  end

  def as_json(*)
    return { licensed: false } if @license.blank?

    {
      licensed: true,
      plan_key: @license.plan_key,
      state: @license.current_state,
      trial: @license.trial?,
      enforce: @license.enforce?,
      starts_at: @license.starts_at,
      expires_at: @license.expires_at,
      days_left: @license.days_left,
      grace_days: @license.grace_days,
      overage_policy: @license.overage_policy,
      usage: usage
    }
  end

  private

  def usage
    metered = Licensing::Usage.snapshot(@account)
    metered.merge(
      'agents' => { used: @account.account_users.count, limit: @license.quota('agents') },
      'inboxes' => { used: @account.inboxes.count, limit: @license.quota('inboxes') },
      'inboxes_by_channel' => channel_usage
    )
  end

  def channel_usage
    limits = @license.quotas['inboxes_by_channel'] || {}
    counts = @account.inboxes.group(:channel_type).count.transform_keys { |type| Licensing::Guard.channel_key(type) }
    limits.to_h { |key, limit| [key, { used: counts[key].to_i, limit: limit }] }
  end
end
