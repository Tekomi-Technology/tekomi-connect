# Applies a preset from config/license_plans.yml to an account by snapshotting its
# features and quotas, so later edits to the preset do not move existing tenants.
class Licensing::PlanAssigner
  PLANS_PATH = Rails.root.join('config/license_plans.yml')

  class UnknownPlan < StandardError; end

  def self.plans
    @plans ||= YAML.safe_load_file(PLANS_PATH).freeze
  end

  def self.reload!
    @plans = nil
  end

  def initialize(account:, plan_key:, enforce: nil, starts_at: Time.current, duration_days: nil)
    @account = account
    @plan_key = plan_key.to_s
    @enforce = enforce
    @starts_at = starts_at
    @duration_days = duration_days
  end

  def perform
    plan = self.class.plans[@plan_key] || raise(UnknownPlan, @plan_key)

    ActiveRecord::Base.transaction do
      license = @account.account_license || @account.build_account_license
      license.assign_attributes(attrs_for(plan, license))
      license.save!
      apply_features(plan['features'])
      license
    end
  end

  private

  def attrs_for(plan, license)
    days = @duration_days || plan['duration_days']
    {
      plan_key: @plan_key,
      trial: plan['trial'] == true,
      suspended: false,
      starts_at: @starts_at,
      expires_at: days.present? ? @starts_at + days.to_i.days : nil,
      grace_days: plan['grace_days'] || 3,
      overage_policy: plan['overage_policy'] || 'block',
      quotas: plan['quotas'] || {},
      notified: {},
      enforce: @enforce.nil? ? license.enforce : @enforce
    }
  end

  # Only flags that a preset manages are touched, so unrelated account flags survive.
  def apply_features(features)
    features = Array(features)
    managed = self.class.plans.values.flat_map { |p| Array(p['features']) }.uniq
    @account.disable_features(*(managed - features))
    @account.enable_features(*features)
    @account.save!
  end
end
