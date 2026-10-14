# == Schema Information
#
# Table name: account_licenses
#
#  id             :bigint           not null, primary key
#  enforce        :boolean          default(FALSE), not null
#  expires_at     :datetime
#  grace_days     :integer          default(3), not null
#  notified       :jsonb            not null
#  overage_policy :string           default("block"), not null
#  plan_key       :string           default("custom"), not null
#  quotas         :jsonb            not null
#  starts_at      :datetime         not null
#  state          :string           default("active"), not null
#  suspended      :boolean          default(FALSE), not null
#  trial          :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_account_licenses_on_account_id  (account_id) UNIQUE
#  index_account_licenses_on_state       (state)
#
class AccountLicense < ApplicationRecord
  STATES = %w[trial active grace restricted suspended].freeze
  OVERAGE_POLICIES = %w[block allow].freeze
  METRICS = %w[messages calls call_minutes].freeze
  COUNT_QUOTAS = %w[agents inboxes].freeze

  belongs_to :account

  before_validation :set_defaults
  before_save :refresh_state

  validates :state, inclusion: { in: STATES }
  validates :overage_policy, inclusion: { in: OVERAGE_POLICIES }
  validates :grace_days, numericality: { greater_than_or_equal_to: 0 }
  validate :quotas_shape

  # State is derived from the clock so enforcement never depends on job lag;
  # the persisted `state` column is a cache for filtering and dashboards.
  def current_state(now = Time.current)
    return 'suspended' if suspended?
    return trial? ? 'trial' : 'active' if expires_at.blank? || now < expires_at
    return 'grace' if now < expires_at + grace_days.days

    'restricted'
  end

  def refresh_state
    self.state = current_state
  end

  def restricted?
    %w[restricted suspended].include?(current_state)
  end

  def days_left(now = Time.current)
    return nil if expires_at.blank?

    ((expires_at - now) / 1.day).ceil
  end

  def quota(key)
    value = quotas[key.to_s]
    value.nil? ? nil : value
  end

  def inbox_channel_limit(channel_key)
    limits = quotas['inboxes_by_channel']
    return nil unless limits.is_a?(Hash)

    limits[channel_key.to_s]
  end

  # Trials are counted over their whole life; paid plans over rolling periods anchored at starts_at.
  def period_start(now = Time.current)
    anchor = starts_at.to_date
    return anchor if trial?

    months = ((now.year * 12 + now.month) - (anchor.year * 12 + anchor.month))
    candidate = anchor >> months
    candidate = anchor >> (months - 1) if candidate > now.to_date
    candidate
  end

  def period_end(now = Time.current)
    trial? ? expires_at : (period_start(now) >> 1).in_time_zone
  end

  private

  def set_defaults
    self.starts_at ||= Time.current
    self.quotas = {} if quotas.blank?
  end

  def quotas_shape
    return errors.add(:quotas, 'must be an object') unless quotas.is_a?(Hash)

    (METRICS + COUNT_QUOTAS).each do |key|
      value = quotas[key]
      errors.add(:quotas, "#{key} must be a non-negative integer") unless value.nil? || (value.is_a?(Integer) && value >= 0)
    end
  end
end
