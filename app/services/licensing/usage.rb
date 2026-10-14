# Reads and records metered usage (messages, calls, call_minutes) for the current license period.
class Licensing::Usage
  def self.record!(account, metric, amount = 1)
    return if amount.to_i <= 0

    license = account.account_license
    return if license.blank?

    AccountUsageCounter.add!(account_id: account.id, metric: metric, period_start: license.period_start, amount: amount.to_i)
  end

  def self.used(account, metric)
    license = account.account_license
    return 0 if license.blank?

    AccountUsageCounter.where(account_id: account.id, metric: metric.to_s, period_start: license.period_start).sum(:used)
  end

  def self.snapshot(account)
    license = account.account_license
    return nil if license.blank?

    AccountLicense::METRICS.index_with do |metric|
      { used: used(account, metric), limit: license.quota(metric) }
    end
  end
end
