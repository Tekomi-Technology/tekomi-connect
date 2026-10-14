# == Schema Information
#
# Table name: account_usage_counters
#
#  id           :bigint           not null, primary key
#  metric       :string           not null
#  period_start :date             not null
#  used         :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_account_usage_counters_on_account_id  (account_id)
#  index_usage_counters_on_account_metric_period  (account_id,metric,period_start) UNIQUE
#
class AccountUsageCounter < ApplicationRecord
  belongs_to :account

  # Atomic upsert; safe under concurrent senders.
  def self.add!(account_id:, metric:, period_start:, amount: 1)
    now = Time.current
    connection.execute(sanitize_sql_array([<<~SQL.squish, account_id, metric.to_s, period_start, amount, now, now]))
      INSERT INTO account_usage_counters (account_id, metric, period_start, used, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT (account_id, metric, period_start)
      DO UPDATE SET used = account_usage_counters.used + EXCLUDED.used, updated_at = EXCLUDED.updated_at
    SQL
  end
end
